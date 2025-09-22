package com.stardylog.user;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;

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
}
