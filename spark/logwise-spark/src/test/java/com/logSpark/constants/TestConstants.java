package com.logSpark.constants;

import static com.logSpark.tests.constants.Constants.getProperty;

import com.logSpark.tests.TestType;
import java.util.function.UnaryOperator;
import lombok.experimental.UtilityClass;

@UtilityClass
public class TestConstants {
  public final TestType EXISTING_TEST_RUN_TYPE = TestType.valueOf(getProperty("TEST_RUN_TYPE"));
  public final String TEST_DATA_DIR = "src/test/resources/testData";
  public final UnaryOperator<String> TEST_DATA_PATH = fileName -> TEST_DATA_DIR + "/" + fileName;
}
