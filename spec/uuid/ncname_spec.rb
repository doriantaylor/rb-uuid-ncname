RSpec.describe UUID::NCName do
  it "has a version number" do
    expect(UUID::NCName::VERSION).not_to be nil
  end

  uu   = 'c89e701a-acf2-4dd5-9401-539c1fcf15cb'
  nc64 = 'EyJ5wGqzy3VlAFTnB_PFcL'
  nc32 = 'Ezcphagvm6lovsqavhha7z4k4l'

  it "turns a UUID into an NCName" do
    expect(UUID::NCName.to_ncname(uu)).to eq(nc64)
    expect(UUID::NCName.to_ncname_32(uu)).to eq(nc32)
  end

  it "returns an appropriately-formatted NCName back to a UUID" do
    expect(UUID::NCName.from_ncname(nc64)).to eq(uu)
    expect(UUID::NCName.from_ncname(nc32)).to eq(uu)
  end

  it "responds properly to a radix" do
    expect(UUID::NCName.to_ncname(uu, radix: 64)).to eq(nc64)
    expect { UUID::NCName.to_ncname(uu, radix: :derp) }.to raise_error(
      RuntimeError)
  end
end
