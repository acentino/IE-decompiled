#include "nds_rom.hpp"
#include <algorithm>
#include <fstream>
#include <functional>
#include <iterator>
#include <stdexcept>

namespace ie1 {
namespace {
std::uint16_t read16(const std::vector<std::uint8_t>& b, std::size_t p) {
    if (p > b.size() || b.size()-p < 2) throw std::runtime_error("Truncated 16-bit field");
    return static_cast<std::uint16_t>(b[p] | (std::uint16_t(b[p+1]) << 8));
}
std::uint32_t read32(const std::vector<std::uint8_t>& b, std::size_t p) {
    if (p > b.size() || b.size()-p < 4) throw std::runtime_error("Truncated 32-bit field");
    return std::uint32_t(b[p]) | (std::uint32_t(b[p+1]) << 8)
        | (std::uint32_t(b[p+2]) << 16) | (std::uint32_t(b[p+3]) << 24);
}
std::vector<std::uint8_t> slice(const std::vector<std::uint8_t>& b, std::size_t p, std::size_t n) {
    if (p > b.size() || n > b.size()-p) throw std::runtime_error("Read exceeds ROM boundary");
    return {b.begin()+static_cast<std::ptrdiff_t>(p), b.begin()+static_cast<std::ptrdiff_t>(p+n)};
}
}

NdsRom::NdsRom(const std::filesystem::path& rom_path) {
    std::ifstream f(rom_path, std::ios::binary);
    if (!f) throw std::runtime_error("Cannot open ROM: " + rom_path.string());
    rom_.assign(std::istreambuf_iterator<char>(f), std::istreambuf_iterator<char>());
    if (rom_.size() < 0x200 || rom_.size() > 512ull*1024*1024)
        throw std::runtime_error("Invalid or excessively large NDS image");
    title_.assign(reinterpret_cast<const char*>(rom_.data()), 12);
    auto end = title_.find('\0'); if (end != std::string::npos) title_.resize(end);
    game_code_.assign(reinterpret_cast<const char*>(rom_.data()+0x0C), 4);
    if (game_code_ != "YEEF") throw std::runtime_error("This starter targets French Inazuma Eleven 1 (YEEF), received: " + game_code_);
    auto arm = [this](std::size_t p) {
        ArmBinary a{u32(p),u32(p+4),u32(p+8),u32(p+12)};
        check_range(a.offset,a.size);
        return a;
    };
    arm9_ = arm(0x20); arm7_ = arm(0x30);
    auto fnt_off = u32(0x40), fnt_size = u32(0x44);
    auto fat_off = u32(0x48), fat_size = u32(0x4C);
    auto ov_off = u32(0x50), ov_size = u32(0x54);
    check_range(fnt_off,fnt_size); check_range(fat_off,fat_size); check_range(ov_off,ov_size);
    if (fat_size % 8 || ov_size % 32 || fnt_size < 8)
        throw std::runtime_error("Malformed filesystem or overlay table size");
    const auto fnt = slice(rom_,fnt_off,fnt_size);
    const std::size_t file_count = fat_size / 8;
    const std::size_t dir_count = read16(fnt,6);
    if (dir_count == 0 || dir_count*8 > fnt.size())
        throw std::runtime_error("Invalid directory table size");
    files_.reserve(file_count);
    for (std::size_t id=0;id<file_count;id++) {
        auto begin=u32(fat_off+id*8), finish=u32(fat_off+id*8+4);
        if (finish < begin) throw std::runtime_error("Backwards FAT entry");
        check_range(begin,finish-begin);
        files_.push_back({static_cast<std::uint32_t>(id),begin,finish,""});
    }
    std::vector<bool> visited(dir_count,false);
    std::function<void(std::uint32_t,const std::string&,int)> walk;
    walk = [&](std::uint32_t directory, const std::string& prefix, int depth) {
        if (depth > 32 || directory < 0xF000 || directory >= 0xF000+dir_count)
            throw std::runtime_error("Malformed directory reference");
        auto dir_index = directory - 0xF000;
        if (visited[dir_index]) throw std::runtime_error("Directory cycle detected");
        visited[dir_index] = true;
        std::size_t p = read32(fnt,dir_index*8);
        std::size_t file_id = read16(fnt,dir_index*8+4);
        while (true) {
            if (p>=fnt.size()) throw std::runtime_error("Invalid FNT name stream");
            std::uint8_t tag=fnt[p++];
            if (tag==0) break;
            auto size=std::size_t(tag & 0x7F);
            if (size > fnt.size()-p) throw std::runtime_error("Invalid FNT filename length");
            std::string name(reinterpret_cast<const char*>(fnt.data()+p), size); p+=size;
            if (name=="." || name==".." || name.find('/') != std::string::npos || name.find('\\')!=std::string::npos)
                throw std::runtime_error("Unsafe FNT name");
            if (tag & 0x80) {auto child=read16(fnt,p);p+=2;walk(child,prefix+name+"/",depth+1);}
            else {
                if (file_id>=files_.size()) throw std::runtime_error("FNT file ID out of range");
                files_[file_id++].path=prefix+name;
            }
        }
    };
    walk(0xF000,"",0);
    for (std::size_t i=0; i<ov_size/32; i++) {
        auto p=std::size_t(ov_off)+i*32;
        Overlay o{u32(p),u32(p+4),u32(p+8),u32(p+12),u32(p+16),u32(p+20),u32(p+24),u32(p+28)};
        if (o.file_id>=files_.size())throw std::runtime_error("Overlay file ID invalid");
        overlays_.push_back(o);
    }
}
std::uint16_t NdsRom::u16(std::size_t p) const{return read16(rom_,p);}
std::uint32_t NdsRom::u32(std::size_t p) const{return read32(rom_,p);}
void NdsRom::check_range(std::size_t p,std::size_t n) const{
    if (p>rom_.size() || n>rom_.size()-p)throw std::runtime_error("ROM offset outside image");
}
std::optional<FileEntry> NdsRom::find(const std::string& path) const {
    auto it=std::find_if(files_.begin(),files_.end(),[&](const FileEntry& f){return f.path==path;});
    if (it==files_.end())return std::nullopt;
    return *it;
}
std::vector<std::uint8_t> NdsRom::file(std::size_t id) const{
    if(id>=files_.size())throw std::runtime_error("File ID outside FAT");
    return slice(rom_,files_[id].start,files_[id].end-files_[id].start);
}
std::vector<std::uint8_t> NdsRom::binary(const ArmBinary& bin) const{
    return slice(rom_,bin.offset,bin.size);
}
std::vector<std::uint8_t> NdsRom::decompress_lz10(const std::vector<std::uint8_t>& b){
    if (b.size()<4 || b[0]!=0x10)throw std::runtime_error("Not an LZ10 block");
    std::size_t expected=std::size_t(b[1])|(std::size_t(b[2])<<8)|(std::size_t(b[3])<<16);
    if (expected>128ull*1024*1024)throw std::runtime_error("LZ10 output too big");
    std::vector<std::uint8_t> out;out.reserve(expected);
    std::size_t pos=4;
    while(out.size()<expected){
        if(pos>=b.size())throw std::runtime_error("Truncated LZ10 flags");
        auto flags=b[pos++];
        for(int bit=7;bit>=0 && out.size()<expected;bit--){
            if(flags&(1<<bit)){
                if(pos+2>b.size())throw std::runtime_error("Truncated LZ10 match");
                auto value=std::uint32_t(b[pos])<<8|b[pos+1]; pos+=2;
                std::size_t count=(value>>12)+3, dist=(value&0xFFF)+1;
                if(dist>out.size() || out.size()+count>expected)throw std::runtime_error("Invalid LZ10 backreference");
                for(std::size_t n=0;n<count;n++)out.push_back(out[out.size()-dist]);
            }else{
                if(pos>=b.size())throw std::runtime_error("Truncated LZ10 literal");
                out.push_back(b[pos++]);
            }
        }
    }
    return out;
}
std::vector<std::uint8_t> NdsRom::decompress_blz(const std::vector<std::uint8_t>& b){
    if(b.size()<8)throw std::runtime_error("BLZ block too small");
    auto meta=read32(b,b.size()-8),extra=read32(b,b.size()-4);
    std::size_t header=meta>>24,compressed_len=meta&0xFFFFFF;
    if(header<8 || compressed_len> b.size() || header>compressed_len || !extra)
        throw std::runtime_error("Not a compressed BLZ block");
    if (!std::all_of(b.end()-static_cast<std::ptrdiff_t>(header),b.end()-8,
                     [](std::uint8_t c){return c==0xFF;}))
        throw std::runtime_error("BLZ header padding invalid");
    std::size_t prefix=b.size()-compressed_len;
    auto payload=slice(b,prefix,compressed_len-header);
    std::size_t decompressed_len=compressed_len+extra;
    if (decompressed_len > 32ull*1024*1024)throw std::runtime_error("BLZ output too large");
    std::vector<std::uint8_t> out(decompressed_len);
    std::size_t index=payload.size(), written=0;
    while(written<out.size()){
        if(!index)throw std::runtime_error("BLZ ended early at flags");
        auto flags=payload[--index];
        for(int bit=7;bit>=0 && written<out.size();bit--){
            if(flags & (1<<bit)){
                if(index<2)throw std::runtime_error("BLZ match truncated");
                auto high=payload[--index],low=payload[--index];
                std::size_t count=(high>>4)+3;
                std::size_t distance=(((high&15)<<8)|low)+3;
                if(distance>written)throw std::runtime_error("BLZ invalid backreference");
                for(std::size_t j=0;j<count && written<out.size();j++){
                    out[out.size()-1-written]=out[out.size()-1-(written-distance)];
                    written++;
                }
            }else{
                if(!index)throw std::runtime_error("BLZ literal truncated");
                out[out.size()-1-written]=payload[--index];
                written++;
            }
        }
    }
    std::vector<std::uint8_t> result;
    result.reserve(b.size()+extra);
    result.insert(result.end(),b.begin(),b.begin()+static_cast<std::ptrdiff_t>(prefix));
    result.insert(result.end(),out.begin(),out.end());
    return result;
}
std::vector<std::uint8_t> NdsRom::overlay_data(const Overlay& o,bool decompress) const {
    auto raw=file(o.file_id);
    if (!decompress || !(o.flags & 0x01000000))return raw;
    auto uncompressed=decompress_blz(raw);
    if (uncompressed.size()!=o.ram_size)throw std::runtime_error("Overlay decompressed length mismatch");
    return uncompressed;
}
}
