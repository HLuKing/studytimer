package com.stardylog.api;

import com.stardylog.api.dto.StudyLogRequest;
import com.stardylog.api.dto.StudyLogResponse;
import com.stardylog.log.StudyLog;
import com.stardylog.log.StudyLogRepository;
import com.stardylog.user.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.stream.Collectors;

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

    @GetMapping("/study")
    public List<StudyLogResponse> getStudyLogs(Authentication auth) {
        String uid = (String) auth.getPrincipal();

        List<StudyLog> logs = studyLogRepository.findByUserUid(uid);

        return logs.stream()
                .map(StudyLogResponse::new)
                .collect(Collectors.toList());
    }
}
