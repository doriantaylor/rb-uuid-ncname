RSpec.describe UUID::NCName do
  it "has a version number" do
    expect(UUID::NCName::VERSION).not_to be nil
  end

  uu       = 'c89e701a-acf2-4dd5-9401-539c1fcf15cb'
  nc64_old = 'EyJ5wGqzy3VlAFTnB_PFcL'
  nc58_old = 'E6cY7FWJq7qBoK5bPN34EXL'
  nc32_old = 'ezcphagvm6lovsqavhha7z4k4l'
  nc64     = 'EyJ5wGqzy3VQBU5wfzxXLJ'
  nc58     = 'E6cY7FWJq7qAvRnKKVWZ4NJ'
  nc32     = 'ezcphagvm6loviakttqp46folj'

  it "turns a UUID into an NCName (old version)" do
    expect(UUID::NCName.to_ncname(uu, version: 0)).to eq(nc64_old)
    expect(UUID::NCName.to_ncname_32(uu, version: 0)).to eq(nc32_old)
    expect(UUID::NCName.to_ncname_58(uu, version: 0)).to eq(nc58_old)
  end

  it "turns a UUID into an NCName (new version)" do
    expect(UUID::NCName.to_ncname(uu, version: 1)).to eq(nc64)
    expect(UUID::NCName.to_ncname_32(uu, version: 1)).to eq(nc32)
    expect(UUID::NCName.to_ncname_58(uu, version: 1)).to eq(nc58)
  end

  it "returns an appropriately-formatted NCName back to a UUID (old)" do
    expect(UUID::NCName.from_ncname(nc64_old, version: 0)).to eq(uu)
    expect(UUID::NCName.from_ncname(nc32_old, version: 0)).to eq(uu)
    expect(UUID::NCName.from_ncname(nc58_old, version: 0)).to eq(uu)
  end

  it "returns an appropriately-formatted NCName back to a UUID (new)" do
    expect(UUID::NCName.from_ncname(nc64, version: 1)).to eq(uu)
    expect(UUID::NCName.from_ncname(nc32, version: 1)).to eq(uu)
    expect(UUID::NCName.from_ncname(nc58, version: 1)).to eq(uu)
  end

  it "responds properly to a radix" do
    expect(UUID::NCName.to_ncname(uu, radix: 64, version: 1)).to eq(nc64)
    expect { UUID::NCName.to_ncname(uu, radix: :derp) }.to raise_error(
      RuntimeError)
  end

  it "can tell if a token is a UUID NCName" do
    expect(UUID::NCName.valid? 'derp').to eq(false)
    # lol it turns out i need a better uuid to test with
    # expect(UUID::NCName.valid? nc64_old).to eq(0)
    # expect(UUID::NCName.valid? nc32_old).to eq(0)
    expect(UUID::NCName.valid? nc64).to eq(1)
    expect(UUID::NCName.valid? nc32).to eq(1)
    expect do
      UUID::NCName.valid? nc64_old, strict: true
    end.to raise_error(UUID::NCName::AmbiguousToken)
  end
end
