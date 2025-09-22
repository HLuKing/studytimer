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
                User u = userRepository.findById(decoded.getUid())
                        .orElse(User.builder()
                                .uid(decoded.getUid())
                                .createdAt(Instant.now())
                                .build());
                u.setEmail(decoded.getEmail());
                u.setDisplayName(decoded.getName());
                u.setProvider(provider);
                u.setLastLoginAt(Instant.now());
                userRepository.save(u);

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
