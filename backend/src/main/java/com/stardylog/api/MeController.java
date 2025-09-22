package com.stardylog.api;

import com.stardylog.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;


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
}
