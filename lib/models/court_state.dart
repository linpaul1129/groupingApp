/// 單一場地的生命週期狀態。
///
/// - [pending]：人員已排定，尚未開始比賽；可與等待區玩家拖拉互換。
/// - [playing]：比賽進行中；無法換人，只能按結束鍵輸入比分。
enum CourtState { pending, playing }
