require "minitest/autorun"
require "json"
require_relative "../lib/station_directory"

class StationDirectoryTest < Minitest::Test
  FIXTURE = {
    "regions" => {
      "hakodate" => {
        "name" => "函館市",
        "prefecture" => "北海道",
        "stations" => [
          { "freq_khz" => 79_400, "name" => "FM NORTHWAVE", "kind" => "fm" },
          { "freq_khz" => 80_700, "name" => "FMいるか", "kind" => "community" },
          { "freq_khz" => 87_000, "name" => "NHK-FM 函館", "kind" => "fm" }
        ]
      }
    }
  }.freeze

  def test_regionsは登録地域キーの配列を返す
    dir = StationDirectory.new(FIXTURE)
    assert_equal ["hakodate"], dir.regions
  end

  def test_stationsは指定地域の局リストを返す
    dir = StationDirectory.new(FIXTURE)
    assert_equal 3, dir.stations("hakodate").size
    assert_equal "FMいるか", dir.stations("hakodate")[1]["name"]
  end

  def test_存在しない地域のstationsは空配列を返す
    dir = StationDirectory.new(FIXTURE)
    assert_equal [], dir.stations("sapporo")
  end

  def test_完全一致の周波数でプリセットを引ける
    dir = StationDirectory.new(FIXTURE)
    match = dir.lookup("hakodate", 80_700_000)
    assert_equal "FMいるか", match["name"]
  end

  def test_20kHz以内のズレでも引ける
    dir = StationDirectory.new(FIXTURE)
    match = dir.lookup("hakodate", 80_720_000)
    assert_equal "FMいるか", match["name"]
  end

  def test_50kHz境界はヒットする
    dir = StationDirectory.new(FIXTURE)
    match = dir.lookup("hakodate", 80_750_000)
    assert_equal "FMいるか", match["name"]
  end

  def test_51kHz外れるとヒットしない
    dir = StationDirectory.new(FIXTURE)
    assert_nil dir.lookup("hakodate", 80_751_000)
  end

  def test_50kHzをわずかに超える周波数はヒットしない
    dir = StationDirectory.new(FIXTURE)
    assert_nil dir.lookup("hakodate", 80_750_999)
  end

  def test_登録されていない周波数はnil
    dir = StationDirectory.new(FIXTURE)
    assert_nil dir.lookup("hakodate", 82_500_000)
  end

  def test_存在しない地域のlookupはnil
    dir = StationDirectory.new(FIXTURE)
    assert_nil dir.lookup("sapporo", 80_700_000)
  end
end

class StationDirectoryDataTest < Minitest::Test
  STATIONS_DATA = JSON.parse(
    File.read(File.join(__dir__, "../data/stations.json"))
  ).freeze
  FREQ_MIN_KHZ = 76_000
  FREQ_MAX_KHZ = 95_000

  STATIONS_DATA["regions"].keys.each do |region|
    define_method(:"test_#{region}_は空でない局リストを返す") do
      dir = StationDirectory.new(STATIONS_DATA)
      assert_operator dir.stations(region).size, :>, 0
    end

    define_method(:"test_#{region}_の全周波数はスキャン範囲内") do
      dir = StationDirectory.new(STATIONS_DATA)
      dir.stations(region).each do |s|
        assert_operator s["freq_khz"], :>=, FREQ_MIN_KHZ,
          "#{s["name"]} の #{s["freq_khz"]} kHz が下限を下回っている"
        assert_operator s["freq_khz"], :<=, FREQ_MAX_KHZ,
          "#{s["name"]} の #{s["freq_khz"]} kHz が上限を超えている"
      end
    end
  end
end
