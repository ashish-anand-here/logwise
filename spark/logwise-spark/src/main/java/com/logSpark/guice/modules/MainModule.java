package com.logSpark.guice.modules;

import com.logSpark.clients.*;
import com.logSpark.clients.impl.FeignClientImpl;
import com.google.inject.AbstractModule;
import com.typesafe.config.Config;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class MainModule extends AbstractModule {
  private final Config config;

  @Override
  protected void configure() {
    bind(Config.class).toInstance(config);
    bind(FeignClient.class).to(FeignClientImpl.class);
    bind(SparkMasterClient.class).toInstance(getSparkMasterClient());
    bind(KafkaManagerClient.class).toInstance(getKafkaManagerClient());
    bind(LogCentralOrchestratorClient.class).toInstance(getLogCentralOrchestratorClient());
  }

  private SparkMasterClient getSparkMasterClient() {
    String url = config.getString("spark.master.host");
    return new FeignClientImpl().createClient(SparkMasterClient.class, url);
  }

  private KafkaManagerClient getKafkaManagerClient() {
    String url = config.getString("kafka.manager.host");
    return new FeignClientImpl().createClient(KafkaManagerClient.class, url);
  }

  private LogCentralOrchestratorClient getLogCentralOrchestratorClient() {
    String url = config.getString("logCentral.orchestrator.url");
    return new FeignClientImpl().createClient(LogCentralOrchestratorClient.class, url);
  }
}