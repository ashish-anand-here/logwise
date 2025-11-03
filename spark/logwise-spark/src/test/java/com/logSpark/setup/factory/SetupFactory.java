package com.logSpark.setup.factory;

import com.logSpark.setup.Setup;
import com.logSpark.setup.impl.BlackBoxSetup;
import com.logSpark.setup.impl.UnitTestSetup;
import com.logSpark.setup.impl.WhiteBoxSetup;
import com.logSpark.tests.TestType;
import javax.validation.constraints.NotNull;

public class SetupFactory {
  public static Setup getSetup(@NotNull TestType testType) {
    switch (testType) {
      case WHITEBOX_TESTS:
        return new WhiteBoxSetup();
      case BLACKBOX_TESTS:
        return new BlackBoxSetup();
      case UNIT_TESTS:
        return new UnitTestSetup();
      default:
        throw new IllegalArgumentException("Invalid test type");
    }
  }
}
