#include "nds_rom.hpp"
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
using namespace ie1;
namespace fs=std::filesystem;
static void save(const fs::path& p,const std::vector<std::uint8_t>& data){
    if(p.has_parent_path())fs::create_directories(p.parent_path());
    std::ofstream f(p,std::ios::binary);
    if(!f)throw std::runtime_error("Unable to create file: "+p.string());
    f.write(reinterpret_cast<const char*>(data.data()),static_cast<std::streamsize>(data.size()));
    if(!f)throw std::runtime_error("Unable to write file: "+p.string());
}
static void usage(){
    std::cerr<<"Usage: ie1_romtool <your-original.nds> <command> [arguments]\n"
       <<"Commands:\n"
       <<"  info                         Show ROM / CPU / filesystem details\n"
       <<"  list [prefix]                List NitroFS files\n"
       <<"  extract <nitrofs-path> <out> [--lz10]  Extract one file\n"
       <<"  dump-code <directory>        Dump ARM binaries and all decompressed overlays\n"
       <<"  check-overlays               Validate all 91 BLZ overlays\n";
}
int main(int argc,char** argv){
    if (argc==2 && std::string(argv[1])=="--version") {
        std::cout<<"IE1 ROM inspection utility v0.2.0 (not a playable PC port)\n";
        return 0;
    }
    if(argc<3){usage();return 2;}
    try{
        NdsRom rom(argv[1]);
        std::string cmd(argv[2]);
        if(cmd=="info"){
            std::cout<<"Title: "<<rom.title()<<"\nGame code: "<<rom.game_code()
                     <<"\nROM bytes: "<<rom.rom_size()<<"\nNitroFS file IDs: "<<rom.files().size()
                     <<"\nNamed files: ";
            std::size_t named=0;for(auto& e:rom.files())if(!e.path.empty())named++;
            std::cout<<named<<"\nARM9 overlays: "<<rom.overlays().size()<<"\n";
            auto show=[](const char* name,const ArmBinary& b){
                std::cout<<name<<" ROM=0x"<<std::hex<<b.offset<<" load=0x"<<b.load<<" entry=0x"<<b.entry
                         <<std::dec<<" size="<<b.size<<"\n";
            };
            show("ARM9",rom.arm9());show("ARM7",rom.arm7());
        } else if(cmd=="list"){
            std::string prefix=(argc>=4)?argv[3]:"";
            for(auto& e:rom.files())if(!e.path.empty() && e.path.rfind(prefix,0)==0)
                std::cout<<e.id<<"\t"<<e.end-e.start<<"\t"<<e.path<<"\n";
        } else if(cmd=="extract"){
            if(argc<5){usage();return 2;}
            auto e=rom.find(argv[3]);
            if(!e)throw std::runtime_error("NitroFS path not found: "+std::string(argv[3]));
            auto bytes=rom.file(e->id);
            if(argc>=6 && std::string(argv[5])=="--lz10")bytes=NdsRom::decompress_lz10(bytes);
            save(argv[4],bytes);
            std::cout<<"Saved "<<bytes.size()<<" bytes to "<<argv[4]<<"\n";
        } else if(cmd=="dump-code"){
            if(argc<4){usage();return 2;}
            fs::path dir=argv[3];
            fs::create_directories(dir);
            save(dir/"arm9.bin",rom.binary(rom.arm9()));
            save(dir/"arm7.bin",rom.binary(rom.arm7()));
            std::ofstream map(dir/"overlays.csv");
            if(!map)throw std::runtime_error("Unable to create overlay manifest");
            map<<"id,ram_address,ram_size,bss_size,file_id,static_init_start,static_init_end\n";
            for(auto& o:rom.overlays()){
                std::string name="overlay_"+std::to_string(o.id)+".bin";
                save(dir/"overlays"/name,rom.overlay_data(o));
                map<<o.id<<",0x"<<std::hex<<o.address<<std::dec<<","<<o.ram_size<<","<<o.bss_size<<","<<o.file_id
                   <<",0x"<<std::hex<<o.static_init_start<<",0x"<<o.static_init_end<<std::dec<<"\n";
            }
            std::cout<<"Wrote ARM9, ARM7 and "<<rom.overlays().size()<<" uncompressed overlays under "<<dir<<"\n";
        } else if(cmd=="check-overlays"){
            for(auto& o:rom.overlays()){
                if(rom.overlay_data(o).size()!=o.ram_size)
                    throw std::runtime_error("Failed validation at overlay "+std::to_string(o.id));
            }
            std::cout<<"PASS: "<<rom.overlays().size()<<" overlays decompressed and size-checked.\n";
        } else {usage();return 2;}
    }catch(const std::exception& e){std::cerr<<"ERROR: "<<e.what()<<"\n";return 1;}
}
