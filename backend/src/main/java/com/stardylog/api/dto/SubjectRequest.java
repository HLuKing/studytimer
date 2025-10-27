package com.stardylog.api.dto; // 패키지 이름 확인!

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

// 과목 생성/수정 시 클라이언트 -> 서버
public record SubjectRequest(
        @NotBlank
        @Size(max = 50)
        String name,

        @Size(max = 10) // 색상 코드 길이 제한 (예: "FF00AA")
        String color
) {}