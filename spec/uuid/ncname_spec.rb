RSpec.describe UUID::NCName do
  it "has a version number" do
    expect(UUID::NCName::VERSION).not_to be nil
  end

  uu       = 'c89e701a-acf2-4dd5-9401-539c1fcf15cb'
  nc64_old = 'EyJ5wGqzy3VlAFTnB_PFcL'
  nc32_old = 'Ezcphagvm6lovsqavhha7z4k4l'
  nc64     = 'EyJ5wGqzy3VQBU5wfzxXLJ'
  nc32     = 'Ezcphagvm6loviakttqp46folj'

  it "turns a UUID into an NCName (old version)" do
    expect(UUID::NCName.to_ncname(uu, version: 0)).to eq(nc64_old)
    expect(UUID::NCName.to_ncname_32(uu, version: 0)).to eq(nc32_old)
  end

  it "turns a UUID into an NCName (new version)" do
    expect(UUID::NCName.to_ncname(uu, version: 1)).to eq(nc64)
    expect(UUID::NCName.to_ncname_32(uu, version: 1)).to eq(nc32)
  end

  it "returns an appropriately-formatted NCName back to a UUID (old)" do
    expect(UUID::NCName.from_ncname(nc64_old, version: 0)).to eq(uu)
    expect(UUID::NCName.from_ncname(nc32_old, version: 0)).to eq(uu)
  end

  it "returns an appropriately-formatted NCName back to a UUID (new)" do
    expect(UUID::NCName.from_ncname(nc64, version: 1)).to eq(uu)
    expect(UUID::NCName.from_ncname(nc32, version: 1)).to eq(uu)
  end

  it "responds properly to a radix" do
    expect(UUID::NCName.to_ncname(uu, radix: 64, version: 1)).to eq(nc64)
    expect { UUID::NCName.to_ncname(uu, radix: :derp) }.to raise_error(
      RuntimeError)
  end
end
