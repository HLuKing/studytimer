package com.stardylog.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record DisplayNameRequest(
    @NotBlank
    @Size(min = 2, max = 20)
    @Pattern(regexp = "^[a-zA-Z0-9가-힣_]+$",
            message = "닉네임은 한글/영문/숫자/밑줄만 가능합니다.")
    String displayName
) {}
