package com.logSpark.clients;

import com.logSpark.dto.response.TopicIdentitiesResponse;
import feign.Param;
import feign.RequestLine;

public interface KafkaManagerClient {

    @RequestLine("GET /api/status/{clusterName}/topicIdentities")
    TopicIdentitiesResponse topicIdentities(@Param("clusterName") String clusterName);
}