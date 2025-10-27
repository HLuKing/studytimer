package com.stardylog.security;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import com.stardylog.user.User;
import com.stardylog.user.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.util.Optional;
import org.springframework.dao.DataIntegrityViolationException;

import java.time.Instant;
import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
public class FirebaseAuthFilter extends OncePerRequestFilter {

    private final UserRepository userRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws java.io.IOException, jakarta.servlet.ServletException {

        String auth = req.getHeader(HttpHeaders.AUTHORIZATION);
        if (auth != null && auth.startsWith("Bearer ")) {
            String idToken = auth.substring(7);
            try {
                FirebaseToken decoded = FirebaseAuth.getInstance().verifyIdToken(idToken);

                System.out.println("✅ Firebase decoded: uid=" + decoded.getUid() + ", email=" + decoded.getEmail());

                String provider = null;
                Object firebaseClaim = decoded.getClaims().get("firebase");
                if (firebaseClaim instanceof Map<?, ?> m) {
                    Object v = m.get("sign_in_provider");
                    if (v != null) provider = v.toString();
                }

                Optional<User> userOptional = userRepository.findById(decoded.getUid());

                User u;
                if (userOptional.isPresent()) {
                    // 2. [유저가 있을 때] 기존 유저 정보를 업데이트합니다.
                    u = userOptional.get();
                    u.setEmail(decoded.getEmail());
                    u.setProvider(provider);
                    u.setLastLoginAt(Instant.now());
                    userRepository.save(u); // UPDATE 실행
                } else {
                    // 3. [유저가 없을 때] 새 유저를 생성합니다.
                    u = User.builder()
                            .uid(decoded.getUid())
                            .createdAt(Instant.now())
                            .email(decoded.getEmail())
                            .provider(provider)
                            .lastLoginAt(Instant.now())
                            .build();
                    try {
                        userRepository.save(u); // INSERT 시도
                    } catch (DataIntegrityViolationException e) {
                        // 4. [레이스 컨디션] 다른 요청이 방금 INSERT했다면, 오류를 무시합니다.
                        // (이미 유저가 생성되었으므로 이 요청은 성공한 것으로 간주합니다)
                        System.out.println("ℹ️ Race condition handled: User already created by another request. uid=" + decoded.getUid());
                        // (선택사항) u = userRepository.findById(decoded.getUid()).get();
                    }
                }

                var authToken = new AbstractAuthenticationToken(List.of(new SimpleGrantedAuthority("ROLE_USER"))) {
                    @Override public Object getCredentials() {return ""; }
                    @Override public Object getPrincipal() {return decoded.getUid();}
                };
                authToken.setAuthenticated(true);
                SecurityContextHolder.getContext().setAuthentication(authToken);
            } catch (Exception e) {
                res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                return;
            }
        }
        chain.doFilter(req, res);
    }
}
