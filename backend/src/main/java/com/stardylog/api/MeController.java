package com.stardylog.api;

import com.stardylog.api.dto.DisplayNameRequest;
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
    public Object me(Authentication auth) {
        String uid = (String) auth.getPrincipal();
        return userRepository.findById(uid).orElseThrow();
    }

    @PostMapping("/me/display-name")
    public User setDisplayName(Authentication auth, @RequestBody @Valid DisplayNameRequest req) {
        String uid = (String) auth.getPrincipal();
        if (userRepository.existsByDisplayName(req.displayName())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 사용 중인 닉네임입니다.");
        }
        User u = userRepository.findById(uid).orElseThrow();
        u.setDisplayName(req.displayName());
        return userRepository.save(u);
    }
}
