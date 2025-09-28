package com.stardylog.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;

public record StudyLogRequest(
        @NotBlank
        String subjectName,

        @NotNull
        Integer studyDurationSeconds,

        @NotNull
        Integer breakDurationSeconds,

        @NotNull
        Instant endTime
) {
}
