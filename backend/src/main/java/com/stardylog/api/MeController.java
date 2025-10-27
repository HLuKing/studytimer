package com.stardylog.api;

import com.stardylog.api.dto.DisplayNameRequest;
import com.stardylog.api.dto.MeResponse;
import com.stardylog.user.User;
import com.stardylog.user.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;


@RestController
@RequiredArgsConstructor
public class MeController {
    private final UserRepository userRepository;

    @GetMapping("/health")
    public String health() {return "ok"; }

    @GetMapping("/me")
    public MeResponse me(Authentication auth) { // [!] 반환 타입을 Object -> MeResponse 로 변경
        String uid = (String) auth.getPrincipal();
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
        return MeResponse.fromEntity(user); // [!] 엔티티를 DTO로 변환하여 반환
    }

    @PostMapping("/me/display-name")
    public MeResponse setDisplayName(Authentication auth, @RequestBody @Valid DisplayNameRequest req) { // [!] 반환 타입을 User -> MeResponse 로 변경
        String uid = (String) auth.getPrincipal();
        if (userRepository.existsByDisplayName(req.displayName())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 사용 중인 닉네임입니다.");
        }
        User u = userRepository.findById(uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        u.setDisplayName(req.displayName());
        User savedUser = userRepository.save(u); // 일단 저장

        return MeResponse.fromEntity(savedUser); // [!] 저장된 엔티티를 DTO로 변환하여 반환
    }
}
