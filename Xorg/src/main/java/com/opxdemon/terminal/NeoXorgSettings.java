package com.opxdemon.terminal;

import com.opxdemon.terminal.xorg.NeoXorgViewClient;

public class NeoXorgSettings {
  public static void init(NeoXorgViewClient client) {
    Settings.Load(client);
  }
}
