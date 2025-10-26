package com.stardylog.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;

public record StudyLogRequest(
        @NotBlank
        String subjectName,

        @NotBlank
        String sessionId,

        @NotBlank
        String intervalType,

        @NotNull
        Integer durationSeconds,

        @NotNull
        Instant startTime,

        @NotNull
        Instant endTime
) {
}
