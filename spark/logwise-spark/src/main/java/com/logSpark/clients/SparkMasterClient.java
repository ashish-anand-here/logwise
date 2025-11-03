package com.logSpark.clients;

import com.logSpark.dto.response.SparkMasterJsonResponse;
import feign.RequestLine;

public interface SparkMasterClient {
  @RequestLine("GET /json")
  SparkMasterJsonResponse json();
}
