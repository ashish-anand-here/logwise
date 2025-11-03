package com.logSpark.dto.request;

import com.logSpark.dto.entity.SparkStageHistory;
import lombok.Data;

@Data
public class ScaleSparkClusterRequest {
    private Boolean enableUpScale;
    private Boolean enableDownScale;
    private SparkStageHistory sparkStageHistory;
}