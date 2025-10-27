package com.stardylog.api.dto;

import com.stardylog.user.User;
import java.time.Instant;

// 서버 -> 클라이언트로 "내 정보"를 응답할 때 사용할 DTO
public record MeResponse(
        String uid,
        String email,
        String displayName,
        String provider,
        Instant createdAt,
        Instant lastLoginAt
) {
    // User 엔티티를 MeResponse DTO로 변환하는 정적 팩토리 메서드
    public static MeResponse fromEntity(User user) {
        return new MeResponse(
                user.getUid(),
                user.getEmail(),
                user.getDisplayName(),
                user.getProvider(),
                user.getCreatedAt(),
                user.getLastLoginAt()
        );
    }
}