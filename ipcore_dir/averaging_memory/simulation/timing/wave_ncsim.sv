
 
 
 




window new WaveWindow  -name  "Waves for BMG Example Design"
waveform  using  "Waves for BMG Example Design"


      waveform add -signals /averaging_memory_tb/status
      waveform add -signals /averaging_memory_tb/averaging_memory_synth_inst/bmg_port/CLKA
      waveform add -signals /averaging_memory_tb/averaging_memory_synth_inst/bmg_port/ADDRA
      waveform add -signals /averaging_memory_tb/averaging_memory_synth_inst/bmg_port/DINA
      waveform add -signals /averaging_memory_tb/averaging_memory_synth_inst/bmg_port/WEA
      waveform add -signals /averaging_memory_tb/averaging_memory_synth_inst/bmg_port/CLKB
      waveform add -signals /averaging_memory_tb/averaging_memory_synth_inst/bmg_port/ADDRB
      waveform add -signals /averaging_memory_tb/averaging_memory_synth_inst/bmg_port/DOUTB
console submit -using simulator -wait no "run"
