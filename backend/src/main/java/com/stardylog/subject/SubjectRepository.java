package com.stardylog.subject; // 패키지 이름 확인!

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface SubjectRepository extends JpaRepository<Subject, Long> {

    // 특정 사용자의 삭제되지 않은 과목 목록 찾기
    List<Subject> findByUserUidAndDeletedFalseOrderByIdAsc(String userUid);

    // 특정 사용자의 특정 이름(삭제되지 않은) 과목 찾기 (중복 방지용)
    Optional<Subject> findByUserUidAndNameAndDeletedFalse(String userUid, String name);

    // (선택) ID와 사용자 UID로 삭제되지 않은 과목 찾기 (수정/삭제 시 본인 확인용)
    Optional<Subject> findByIdAndUserUidAndDeletedFalse(Long id, String userUid);
}