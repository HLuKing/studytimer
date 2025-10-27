package com.stardylog.subject;

import com.stardylog.user.User;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;

@Entity @Table(name = "subjects")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class Subject {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id; // 숫자 ID (Primary Key)

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_uid", nullable = false) // 어느 사용자의 과목인지 연결
    private User user;

    @Column(nullable = false, length = 50)
    private String name; // 과목 이름 (예: "수학")

    @Column(length = 10) // 색상 코드 저장 (예: "FF0000")
    private String color;

    // (선택) 과목 생성/수정 시간 등 추가 정보
    private Instant createdAt;

    // --- 중요: 소프트 삭제 (Soft Delete) ---
    private boolean deleted = false; // 삭제 여부 플래그
    private Instant deletedAt;      // 삭제 시간 (선택)
}