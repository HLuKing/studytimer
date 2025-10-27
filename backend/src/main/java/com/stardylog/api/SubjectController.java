package com.stardylog.api; // 패키지 이름 확인!

import com.stardylog.api.dto.SubjectRequest; // [!] 나중에 만들 DTO
import com.stardylog.api.dto.SubjectResponse; // [!] 나중에 만들 DTO
import com.stardylog.subject.Subject;
import com.stardylog.subject.SubjectRepository;
import com.stardylog.user.User;
import com.stardylog.user.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/subjects")
@RequiredArgsConstructor
public class SubjectController {

    private final SubjectRepository subjectRepository;
    private final UserRepository userRepository; // User 찾기 위해 필요

    // 1. 내 과목 목록 조회 (삭제되지 않은 것만)
    @GetMapping
    public List<SubjectResponse> getMySubjects(Authentication auth) {
        String uid = (String) auth.getPrincipal();
        List<Subject> subjects = subjectRepository.findByUserUidAndDeletedFalseOrderByIdAsc(uid);
        return subjects.stream().map(SubjectResponse::fromEntity).collect(Collectors.toList());
    }

    // 2. 새 과목 추가
    @PostMapping
    public ResponseEntity<SubjectResponse> addSubject(Authentication auth, @RequestBody @Valid SubjectRequest request) {
        String uid = (String) auth.getPrincipal();
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        // 중복 이름 체크
        subjectRepository.findByUserUidAndNameAndDeletedFalse(uid, request.name())
                .ifPresent(s -> {
                    throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 사용 중인 과목 이름입니다.");
                });

        Subject newSubject = Subject.builder()
                .user(user)
                .name(request.name())
                .color(request.color()) // DTO에서 색상 받기
                .createdAt(Instant.now())
                .deleted(false)
                .build();

        Subject savedSubject = subjectRepository.save(newSubject);
        return ResponseEntity.status(HttpStatus.CREATED).body(SubjectResponse.fromEntity(savedSubject));
    }

    // 3. 과목 수정 (이름, 색상)
    @PutMapping("/{id}")
    public SubjectResponse updateSubject(Authentication auth, @PathVariable Long id, @RequestBody @Valid SubjectRequest request) {
        String uid = (String) auth.getPrincipal();
        Subject subject = subjectRepository.findByIdAndUserUidAndDeletedFalse(id, uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Subject not found or unauthorized"));

        // 수정하려는 이름이 이미 다른 과목에 사용 중인지 체크 (자기 자신 제외)
        subjectRepository.findByUserUidAndNameAndDeletedFalse(uid, request.name())
                .filter(s -> !s.getId().equals(id)) // 자기 자신은 제외
                .ifPresent(s -> {
                    throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 사용 중인 과목 이름입니다.");
                });

        subject.setName(request.name());
        subject.setColor(request.color());
        // (선택) 수정 시간 업데이트 필드 추가 가능
        Subject updatedSubject = subjectRepository.save(subject);
        return SubjectResponse.fromEntity(updatedSubject);
    }

    // 4. 과목 삭제 (논리적 삭제 - Soft Delete)
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteSubject(Authentication auth, @PathVariable Long id) {
        String uid = (String) auth.getPrincipal();
        Subject subject = subjectRepository.findByIdAndUserUidAndDeletedFalse(id, uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Subject not found or unauthorized"));

        subject.setDeleted(true);
        subject.setDeletedAt(Instant.now()); // 삭제 시간 기록 (선택 사항)
        subjectRepository.save(subject);

        return ResponseEntity.noContent().build(); // 성공 시 204 No Content 반환
    }
}