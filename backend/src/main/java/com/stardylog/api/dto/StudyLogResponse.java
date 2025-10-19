package com.stardylog.api.dto;

import com.stardylog.log.StudyLog;
import java.time.Instant;

// Flutter 앱으로 보낼 공부 기록 DTO
public record StudyLogResponse(
        Long id,
        String subjectName,
        int studyDurationSeconds,
        int breakDurationSeconds,
        Instant endTime
) {
    // StudyLog 엔티티를 DTO로 변환하는 생성자
    public StudyLogResponse(StudyLog log) {
        this(
                log.getId(),
                log.getSubjectName(),
                log.getStudyDurationSeconds(),
                log.getBreakDurationSeconds(),
                log.getEndTime()
        );
    }
}