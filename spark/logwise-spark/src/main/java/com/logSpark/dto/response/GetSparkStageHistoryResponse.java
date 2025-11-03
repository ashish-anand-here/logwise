package com.logSpark.dto.response;

import com.logSpark.dto.entity.SparkStageHistory;
import java.util.List;
import lombok.Data;

@Data
public class GetSparkStageHistoryResponse {
    private ResponseData data;

    @Data
    public static class ResponseData {
        private List<SparkStageHistory> sparkStageHistory;
    }
}