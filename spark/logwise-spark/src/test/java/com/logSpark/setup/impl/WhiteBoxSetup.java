package com.logSpark.setup.impl;

import com.logSpark.setup.Setup;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class WhiteBoxSetup implements Setup {
  @Override
  public void setUp() {
    log.info("Setting up WhiteBox Test");
  }

  @Override
  public void tearDown() {
    log.info("Tearing down WhiteBox Test");
  }
}
