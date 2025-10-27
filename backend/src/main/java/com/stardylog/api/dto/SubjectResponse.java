package com.stardylog.api.dto; // 패키지 이름 확인!

import com.stardylog.subject.Subject;

// 과목 정보 서버 -> 클라이언트
public record SubjectResponse(
        Long id,
        String name,
        String color
        // (선택) createdAt 등 필요한 정보 추가
) {
    // Entity -> DTO 변환을 위한 정적 팩토리 메서드
    public static SubjectResponse fromEntity(Subject subject) {
        return new SubjectResponse(
                subject.getId(),
                subject.getName(),
                subject.getColor()
        );
    }
}