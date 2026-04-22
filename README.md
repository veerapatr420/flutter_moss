<div align="center">
  <h1>💰 Splitmate</h1>
  <p><b>แอปพลิเคชันสำหรับหารบิลกับเพื่อนแบบง่ายๆ จบครบในแอปเดียว</b></p>
  
  ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
  ![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
  ![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
</div>

---

แอปพลิเคชันสำหรับหารค่าใช้จ่ายร่วมกับกลุ่มเพื่อน รองรับการสร้างบิลจากใบเสรจ, คำนวยอดแต่ละบุคคลดยอัตนมัติ, เกบประวัติข้อมลบิล และสามารถประมวลผล QR Code สำหรับการอนเงินผ่าน PromptPay ได้ทันที

## ✨ ฟีเจอรหลัก (Features)

- 📸 **สร้างบิลใหม่** พร้อมแนบรปถ่าย หรือ อัปหลดรปภาพใบเสรจ
- ✏️ **จัดการบิล** แก้ไขรายละเอียดบิลและลบบิลได้ทันทีจากหน้าประวัติ
- 🧮 **คำนวอัตนมัติ** หารยอดค่าใช้จ่ายต่อคนให้เท่าๆ กันอย่างรวดเรว
- 🗂 **ประวัติการใช้งาน** แสดงประวัติและรายการบิลทั้งหมดผ่านานข้อมล **Supabase**
- 👥 **ดรายละเอียดบิล** ตรวจสอบยอดรวม และยอดที่ต้องชำระของแต่ละบุคคล
- 🏦 **รองรับ PromptPay** ตั้งค่าเบอรพร้อมเพย สร้าง QR Code ให้เพื่อนสแกนจ่ายได้ทันที

## 📱 ภาพหน้าจอแอปพลิเคชัน (Screenshots)

<div align="center">
  <table>
    <tr>
      <td align="center"><b>หน้าเริ่มต้น (Splash)</b></td>
      <td align="center"><b>หน้าหลัก (Home)</b></td>
    </tr>
    <tr>
      <td align="center"><img src="docs/screenshots/splash.png" height="500"></td>
      <td align="center"><img src="docs/screenshots/home.png" height="500"></td>
    </tr>
    <tr>
      <td align="center"><b>สร้างบิลใหม่ (Create Bill)</b></td>
      <td align="center"><b>ตั้งค่า PromptPay (Settings)</b></td>
    </tr>
    <tr>
      <td align="center"><img src="docs/screenshots/create-bill.png" height="500"></td>
      <td align="center"><img src="docs/screenshots/setting.png" height="500"></td>
    </tr>
  </table>
</div>

## 🛠 Tech Stack

- **Framework:** Flutter
- **Backend & Database:** Supabase (supabase_flutter)
- **Packages:** image_picker, shared_preferences, qr_flutter

## ⚙️ การตั้งค่าานข้อมล (Supabase Setup)

1. เปิดปรเจกต **Supabase** ของคุ
2. ไปที่ **SQL Editor**
3. คัดลอกคำสั่งจากไฟล migration ของปรเจกตนี้และใช้รันานข้อมล:

   supabase/migrations/20260424_splitmate_public_schema.sql

   > **ครงสร้างที่จะถกสร้างสร้าง:**  
   > - ตาราง public.bills  
   > - ตาราง public.participants  
   > - RLS policy สำหรับใช้งานแบบ Public Access  
   > - Storage bucket ชื่อ eceipts พร้อม Policy ที่เกี่ยวข้อง  

4. ตรวจสอบค่า url และ nonKey ในไฟล lib/main.dart ให้ตรงกับปรเจกตของคุ

## 🚀 วิีติดตั้งและทดสอบรันแอป

`ash
flutter pub get
flutter run
`

## 🗄 ครงสร้างข้อมลดยย่อ

- **ills**: เกบประวัติชื่อบิล, ยอดเงินรวม, จำนวนเงิน, รปใบเสรจ (URL), และวันที่สร้าง
- **participants**: เกบรายชื่อผ้เกี่ยวข้องในแต่ละบิล และยอดที่ต้องรับผิดชอบ

## 💡 หมายเหตุ

- หากรปภาพออนไลนตัวอย่างบางรปในระบบหลดไม่ได้ แอปพลิเคชันมีระบบ Fallback UI (แสดงรปสีพื้นแทน) เพื่อให้สามารถใช้งานได้อย่างปกติต่อเนื่อง
