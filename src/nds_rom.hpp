#pragma once
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace ie1 {
struct FileEntry {
    std::uint32_t id{}, start{}, end{};
    std::string path;
};
struct Overlay {
    std::uint32_t id{}, address{}, ram_size{}, bss_size{};
    std::uint32_t static_init_start{}, static_init_end{}, file_id{}, flags{};
};
struct ArmBinary {
    std::uint32_t offset{}, entry{}, load{}, size{};
};

class NdsRom {
public:
    explicit NdsRom(const std::filesystem::path& rom_path);
    const std::string& title() const { return title_; }
    const std::string& game_code() const { return game_code_; }
    std::size_t rom_size() const { return rom_.size(); }
    const ArmBinary& arm9() const { return arm9_; }
    const ArmBinary& arm7() const { return arm7_; }
    const std::vector<FileEntry>& files() const { return files_; }
    const std::vector<Overlay>& overlays() const { return overlays_; }
    std::optional<FileEntry> find(const std::string& path) const;
    std::vector<std::uint8_t> file(std::size_t id) const;
    std::vector<std::uint8_t> binary(const ArmBinary& bin) const;
    std::vector<std::uint8_t> overlay_data(const Overlay& overlay, bool decompress = true) const;
    static std::vector<std::uint8_t> decompress_lz10(const std::vector<std::uint8_t>& compressed);
    static std::vector<std::uint8_t> decompress_blz(const std::vector<std::uint8_t>& compressed);

private:
    std::vector<std::uint8_t> rom_;
    std::string title_, game_code_;
    ArmBinary arm9_{}, arm7_{};
    std::vector<FileEntry> files_;
    std::vector<Overlay> overlays_;
    std::uint16_t u16(std::size_t offset) const;
    std::uint32_t u32(std::size_t offset) const;
    void check_range(std::size_t offset, std::size_t size) const;
};
}
