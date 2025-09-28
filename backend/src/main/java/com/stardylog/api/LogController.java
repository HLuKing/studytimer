package com.stardylog.api;

import com.stardylog.api.dto.StudyLogRequest;
import com.stardylog.log.StudyLog;
import com.stardylog.log.StudyLogRepository;
import com.stardylog.user.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/logs")
@RequiredArgsConstructor
public class LogController {

    private final UserRepository userRepository;
    private final StudyLogRepository studyLogRepository;

    @PostMapping("/study")
    public ResponseEntity<Void> addStudyLog(Authentication auth, @RequestBody @Valid StudyLogRequest req) {
        String uid = (String) auth.getPrincipal();
        var user = userRepository.findById(uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        StudyLog newLog = StudyLog.builder()
                .user(user)
                .subjectName(req.subjectName())
                .studyDurationSeconds(req.studyDurationSeconds())
                .breakDurationSeconds(req.breakDurationSeconds())
                .endTime(req.endTime())
                .build();

        studyLogRepository.save(newLog);

        return ResponseEntity.ok().build();
    }
}
