import SwiftUI
import AppKit

struct AboutView: View {
    // 앱의 현재 언어 설정을 그대로 반영
    @AppStorage("MF34_AppLanguage") private var savedLanguage: String = AppLanguage.korean.rawValue
    
    @State private var isPressed: Bool = false
    @State private var showMochiBubble: Bool = false
    @State private var clickCount: Int = 0
    
    var isKor: Bool {
        savedLanguage == AppLanguage.korean.rawValue
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // [상단] 키캡 아이콘 및 팝업 말풍선
            ZStack {
                // 1. K 키캡 아이콘
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 82, height: 82)
                        .scaleEffect(isPressed ? 0.88 : 1.0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.45), value: isPressed)
                } else {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                
                // 2. 맨 앞으로 튀어나오는 팝업 말풍선
                if showMochiBubble {
                    Text(clickCount > 5
                         ? (isKor ? "❤️ 앙~~~ 개기모찌!! (˶> <˶) ❤️" : "❤️ Super Kimochi-ii!! (˶> <˶) ❤️")
                         : (isKor ? "✨ 앙~ 기모찌!! ✨" : "✨ Ang~ Kimochi-ii~!! ✨"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.accentRed)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.accentRed.opacity(0.4), radius: 10, x: 0, y: 3)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .offset(y: -54)
                        .zIndex(100)
                }
            }
            .frame(height: 90)
            .contentShape(Rectangle())
            .onTapGesture {
                NSSound(named: "Tink")?.play()
                clickCount += 1
                
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    isPressed = true
                    showMochiBubble = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation {
                        isPressed = false
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showMochiBubble = false
                    }
                }
            }
            
            // [은은한 텍스트 가이드] 테두리/배경 없이 버전과 동일한 회색
            HStack(spacing: 5) {
                // 끝단 'ㅅ' 각도가 크고 시원하게 보이도록 폰트 크기 및 라운디드 볼드 처리
                Text("↑↑")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                
                Text(isKor ? "누르지 마시오" : "Don't click")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.40))
            .padding(.top, 2)
            
            // [앱 타이틀 & 버전]
            VStack(spacing: 3) {
                Text("KeyMochi")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                
                Text("Version 1.0 (Build 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.40))
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 28)
        .frame(width: 300, height: 215)
        .background(Color.deepGrayBg.ignoresSafeArea())
    }
}
