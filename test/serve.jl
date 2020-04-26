using PeaceFounder: PeaceFounderServer, PeaceFounderConfig, addtooken, ticket, config, BraidChain

demespec = DemeSpec(uuid)
deme = Deme(demespec)

server = Signer(deme,"server")

pfconfig = config(deme)
braidchain = BraidChain(deme,pfconfig)
system = PeaceFounderServer(pfconfig,braidchain,server)
