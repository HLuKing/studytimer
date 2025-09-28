package com.stardylog.log;

import com.stardylog.user.User;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;


@Entity
@Table(name = "study_logs")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class StudyLog {

    @Id
    @GeneratedValue(strategy =  GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_uid")
    private User user;

    private String subjectName;
    private int studyDurationSeconds;
    private int breakDurationSeconds;
    private Instant endTime;
}
