package com.logSpark.dto.mapper;

import com.logSpark.dto.entity.KafkaAssignOption;
import com.logSpark.dto.entity.StartingOffsetsByTimestampOption;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.experimental.UtilityClass;

@UtilityClass
public class KafkaAssignOptionMapper {
    public Function<StartingOffsetsByTimestampOption, KafkaAssignOption> toKafkaAssignOption =
            offset -> {
                KafkaAssignOption kafkaAssignOption = new KafkaAssignOption();
                offset
                        .getOffsetByTimestamp()
                        .forEach(
                                (topic, partitionMap) -> {
                                    kafkaAssignOption.addTopic(
                                            topic,
                                            partitionMap.keySet().stream()
                                                    .map(Integer::valueOf)
                                                    .collect(Collectors.toList()));
                                });
                return kafkaAssignOption;
            };
}