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
    public ResponseEntity<Void> addStudyLogs(Authentication auth, @RequestBody @Valid List<StudyLogRequest> requests) {
        String uid = (String) auth.getPrincipal();
        var user = userRepository.findById(uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        List<StudyLog> logsToSave = requests.stream().map(req ->
                StudyLog.builder()
                        .user(user)
                        .sessionId(req.sessionId())
                        .subjectName(req.subjectName())
                        .intervalType(req.intervalType())
                        .durationSeconds(req.durationSeconds())
                        .startTime(req.startTime())
                        .endTime(req.endTime())
                        .build()
        ).toList();

        studyLogRepository.saveAll(logsToSave);

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
