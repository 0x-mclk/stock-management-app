// Firebase Cloud Function - E-posta gönderimi için
// Dosya yolu: functions/index.js

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Gmail SMTP konfigürasyonu (Gerçek uygulamada environment variables kullanın)
const transporter = nodemailer.createTransporter({
  service: "gmail",
  auth: {
    user: "your-app-email@gmail.com",
    pass: "your-app-password", // App password kullanın
  },
});

// Davet e-postası gönderme
exports.sendInvitationEmail = functions.https.onRequest(async (req, res) => {
  try {
    const { email, storeId, invitationId, storeName } = req.body;

    const mailOptions = {
      from: "StockPro <your-app-email@gmail.com>",
      to: email,
      subject: "StockPro'ya Davet Edildiniz - Onay Bekleniyor",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #2A5298, #4A7BC8); color: white; padding: 20px; border-radius: 8px 8px 0 0;">
            <h1 style="margin: 0; font-size: 24px;">StockPro'ya Davetlisiniz!</h1>
          </div>
          
          <div style="background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px;">
            <p style="font-size: 16px; color: #333;">Merhaba,</p>
            
            <p style="font-size: 16px; color: #333;">
              <strong>${
                storeName || "Mağaza"
              }</strong> takımına katılmak için davet edildiniz!
            </p>
            
            <div style="background: #fff3cd; border: 1px solid #ffeeba; color: #856404; padding: 15px; margin: 20px 0; border-radius: 5px;">
              <strong>🔔 Önemli:</strong> Davetiniz admin onayında beklemektedir. 
              Admin tarafından onaylandıktan sonra size bildirim e-postası gelecektir.
            </div>
            
            <h3 style="color: #2A5298;">Sonraki Adımlar:</h3>
            <ol style="color: #333; line-height: 1.6;">
              <li>Admin onayını bekleyin</li>
              <li>Onay bildirimi aldıktan sonra StockPro uygulamasını indirin</li>
              <li>Bu e-posta adresi ile kayıt olun</li>
              <li>Takımınıza katılın!</li>
            </ol>
            
            <div style="margin: 30px 0; text-align: center;">
              <a href="https://play.google.com/store" 
                 style="background: #2A5298; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
                📱 Uygulamayı İndir
              </a>
            </div>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            
            <p style="color: #666; font-size: 14px;">
              <strong>Davet Detayları:</strong><br>
              Store ID: ${storeId}<br>
              Invitation ID: ${invitationId}<br>
              Tarih: ${new Date().toLocaleDateString("tr-TR")}
            </p>
            
            <p style="color: #666; font-size: 12px; margin-top: 30px;">
              Bu e-posta otomatik olarak gönderilmiştir. Lütfen yanıtlamayın.
            </p>
          </div>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);

    res.status(200).json({
      success: true,
      message: "Invitation email sent successfully",
    });
  } catch (error) {
    console.error("Error sending email:", error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// Onay/Red bildirimi e-postası
exports.sendApprovalNotification = functions.https.onRequest(
  async (req, res) => {
    try {
      const { email, storeId, invitationId, storeName, approved, reason } =
        req.body;

      let subject, html;

      if (approved) {
        subject = "Davetiniz Onaylandı - StockPro'ya Katılabilirsiniz!";
        html = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #28a745, #20c997); color: white; padding: 20px; border-radius: 8px 8px 0 0;">
            <h1 style="margin: 0; font-size: 24px;">🎉 Davetiniz Onaylandı!</h1>
          </div>
          
          <div style="background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px;">
            <p style="font-size: 16px; color: #333;">Tebrikler!</p>
            
            <p style="font-size: 16px; color: #333;">
              <strong>${
                storeName || "Mağaza"
              }</strong> takımına katılma davetiniz onaylandı!
            </p>
            
            <div style="background: #d4edda; border: 1px solid #c3e6cb; color: #155724; padding: 15px; margin: 20px 0; border-radius: 5px;">
              <strong>✅ Harika Haber:</strong> Artık StockPro uygulamasını kullanabilirsiniz.
            </div>
            
            <h3 style="color: #28a745;">Şimdi Ne Yapmalısınız:</h3>
            <ol style="color: #333; line-height: 1.6;">
              <li>StockPro uygulamasını indirin</li>
              <li>Bu e-posta adresi ile kayıt olun</li>
              <li>Takımınıza katılın ve çalışmaya başlayın!</li>
            </ol>
            
            <div style="margin: 30px 0; text-align: center;">
              <a href="https://play.google.com/store" 
                 style="background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
                🚀 Hemen Başla
              </a>
            </div>
          </div>
        </div>
      `;
      } else {
        subject = "Davet Durumu Hakkında - StockPro";
        html = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #dc3545, #fd7e14); color: white; padding: 20px; border-radius: 8px 8px 0 0;">
            <h1 style="margin: 0; font-size: 24px;">Davet Durumu</h1>
          </div>
          
          <div style="background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px;">
            <p style="font-size: 16px; color: #333;">Merhaba,</p>
            
            <p style="font-size: 16px; color: #333;">
              Üzgünüz, <strong>${
                storeName || "Mağaza"
              }</strong> takımına katılma davetiniz 
              şu anda onaylanamamıştır.
            </p>
            
            ${
              reason
                ? `
              <div style="background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; padding: 15px; margin: 20px 0; border-radius: 5px;">
                <strong>Sebep:</strong> ${reason}
              </div>
            `
                : ""
            }
            
            <p style="color: #666; font-size: 14px;">
              Daha fazla bilgi için takım yöneticiniz ile iletişime geçebilirsiniz.
            </p>
          </div>
        </div>
      `;
      }

      const mailOptions = {
        from: "StockPro <your-app-email@gmail.com>",
        to: email,
        subject,
        html,
      };

      await transporter.sendMail(mailOptions);

      res.status(200).json({
        success: true,
        message: `${
          approved ? "Approval" : "Rejection"
        } notification sent successfully`,
      });
    } catch (error) {
      console.error("Error sending notification:", error);
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  }
);

// Firestore trigger - Invitation document değişikliklerini dinle
exports.onInvitationStatusChange = functions.firestore
  .document("store_invitations/{invitationId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Status değişimini kontrol et
    if (before.status !== after.status) {
      if (after.status === "approved" || after.status === "rejected") {
        // Otomatik notification gönder
        try {
          const approved = after.status === "approved";

          await transporter.sendMail({
            from: "StockPro <your-app-email@gmail.com>",
            to: after.email,
            subject: approved ? "Davetiniz Onaylandı!" : "Davet Durumu",
            html: approved
              ? `<p>Harika! ${
                  after.storeName || "Mağaza"
                } takımına katılabilirsiniz.</p>`
              : `<p>Davetiniz onaylanamamıştır. ${
                  after.rejectionReason || ""
                }</p>`,
          });

          console.log(
            `Notification sent to ${after.email} for status: ${after.status}`
          );
        } catch (error) {
          console.error("Auto-notification error:", error);
        }
      }
    }
  });
