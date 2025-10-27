package com.stardylog.user;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import com.stardylog.subject.Subject;

@Entity @Table(name = "users")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class User {
    @Id
    private String uid;
    private String email;
    private String displayName;
    private String provider;

    private Instant createdAt;
    private Instant lastLoginAt;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default // Lombok Builder 사용 시 초기화
    private List<Subject> subjects = new ArrayList<>();
}
