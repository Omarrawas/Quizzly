/**
 * Telegram Webhook Handler for Quizzly Support Bot (@QuizzlySuportBot)
 * Handles incoming webhooks, commands (/start, /help, /status, /contact),
 * interactive inline keyboards for categories, user account linking (Phase 8),
 * and automatic ticket creation in Firestore (Phase 3 & 6).
 */

const https = require('https');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } catch (e) {
    // If running in environment without default credentials, init with ambient config
    admin.initializeApp();
  }
}

const db = admin.firestore();

// Helper to send HTTP POST request to Telegram API
function sendTelegramApi(method, payload, botToken) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(payload);
    const options = {
      hostname: 'api.telegram.org',
      port: 443,
      path: `/bot${botToken}/${method}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          resolve({ ok: false, error: e.message });
        }
      });
    });

    req.on('error', (err) => reject(err));
    req.write(data);
    req.end();
  });
}

// Fetch Bot Token from Firestore settings if available, else fallback to env
async function getBotToken() {
  if (process.env.TELEGRAM_BOT_TOKEN) {
    return process.env.TELEGRAM_BOT_TOKEN;
  }
  try {
    const doc = await db.collection('settings').doc('socials').get();
    if (doc.exists && doc.data().telegramBotToken) {
      return doc.data().telegramBotToken;
    }
  } catch (e) {
    console.error('Error reading bot token from Firestore:', e);
  }
  return ''; // Default or configured token
}

const CATEGORIES = {
  cat_sub: '📚 مشاكل الاشتراك',
  cat_pay: '💳 الدفع',
  cat_code: '🔑 رمز التفعيل',
  cat_app: '📱 التطبيق',
  cat_teacher: '👨‍🏫 المعلم',
  cat_suggest: '📝 اقتراح',
  cat_other: '❌ مشكلة أخرى',
};

function buildCategoryKeyboard() {
  return {
    inline_keyboard: [
      [
        { text: '📚 مشاكل الاشتراك', callback_data: 'cat_sub' },
        { text: '💳 الدفع', callback_data: 'cat_pay' },
      ],
      [
        { text: '🔑 رمز التفعيل', callback_data: 'cat_code' },
        { text: '📱 التطبيق', callback_data: 'cat_app' },
      ],
      [
        { text: '👨‍🏫 المعلم', callback_data: 'cat_teacher' },
        { text: '📝 اقتراح', callback_data: 'cat_suggest' },
      ],
      [{ text: '❌ مشكلة أخرى', callback_data: 'cat_other' }],
    ],
  };
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(200).send('Quizzly Telegram Support Webhook Endpoint is Running.');
  }

  const update = req.body;
  if (!update) {
    return res.status(400).send('No update payload');
  }

  const botToken = await getBotToken();
  if (!botToken) {
    console.error('TELEGRAM_BOT_TOKEN missing');
    return res.status(200).send('Bot token not configured');
  }

  try {
    // 1. Handle Callback Queries (Inline Keyboard Buttons)
    if (update.callback_query) {
      const cb = update.callback_query;
      const chatId = cb.message.chat.id;
      const categoryKey = cb.data;
      const categoryName = CATEGORIES[categoryKey] || 'عامة';

      // Answer Callback query popup
      await sendTelegramApi('answerCallbackQuery', { callback_query_id: cb.id }, botToken);

      // Save user session pending category in Firestore
      await db.collection('telegram_sessions').doc(chatId.toString()).set(
        {
          chatId: chatId,
          pendingCategory: categoryName,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await sendTelegramApi(
        'sendMessage',
        {
          chat_id: chatId,
          text: `اخترت: *${categoryName}*\n\nالرجاء كتابة تفاصيل المشكلة أو الرسالة الآن بشرح واضح وسيتم تسجيل تذكرتك فوراً ✍️`,
          parse_mode: 'Markdown',
        },
        botToken
      );
      return res.status(200).send('OK');
    }

    // 2. Handle Text Messages
    if (update.message && update.message.text) {
      const msg = update.message;
      const chatId = msg.chat.id;
      const text = msg.text.trim();
      const telegramUser = msg.from || {};
      const telegramUsername = telegramUser.username ? `@${telegramUser.username}` : '';
      const telegramFullName = [telegramUser.first_name, telegramUser.last_name].filter(Boolean).join(' ') || 'مستخدم تليجرام';

      // Check Command: /start or /start USER_ID (Phase 8 Account Linking)
      if (text.startsWith('/start')) {
        const parts = text.split(' ');
        let linkedUserId = null;
        let linkedUserName = telegramFullName;

        if (parts.length > 1 && parts[1].trim()) {
          linkedUserId = parts[1].trim();

          // Search and update user doc in Firestore
          try {
            const userRef = db.collection('users').doc(linkedUserId);
            const userDoc = await userRef.get();
            if (userDoc.exists) {
              const userData = userDoc.data();
              linkedUserName = userData.name || userData.fullName || telegramFullName;
              await userRef.set(
                {
                  telegramChatId: chatId.toString(),
                  telegramUsername: telegramUsername,
                  telegramLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
              );
            }
          } catch (e) {
            console.error('Error linking user:', e);
          }
        } else {
          // Check if already linked via telegramChatId in users collection
          try {
            const usersSnap = await db.collection('users').where('telegramChatId', '==', chatId.toString()).limit(1).get();
            if (!usersSnap.empty) {
              const uDoc = usersSnap.docs[0];
              linkedUserId = uDoc.id;
              linkedUserName = uDoc.data().name || telegramFullName;
            }
          } catch (e) {
            console.error('Error finding linked user:', e);
          }
        }

        // Save Telegram session
        await db.collection('telegram_sessions').doc(chatId.toString()).set(
          {
            chatId: chatId,
            userId: linkedUserId,
            userName: linkedUserName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        let welcomeText = `👋 أهلاً بك *${linkedUserName}* في مركز دعم كويزلي الشامل!\n\n`;
        if (linkedUserId) {
          welcomeText += `✅ تم التعرف على حسابك وتوثيق ارتباطك بالنظام بنجاح.\n\n`;
        } else {
          welcomeText += `💡 يمكنك ربط حسابك تلقائياً عبر فتح البوت مباشرة من داخل تطبيق كويزلي.\n\n`;
        }
        welcomeText += `يرجى اختيار فئة المشكلة التي تود المساعدة فيها:`;

        await sendTelegramApi(
          'sendMessage',
          {
            chat_id: chatId,
            text: welcomeText,
            parse_mode: 'Markdown',
            reply_markup: buildCategoryKeyboard(),
          },
          botToken
        );
        return res.status(200).send('OK');
      }

      // Check Command: /help (Phase 7)
      if (text === '/help') {
        const helpText =
          `ℹ️ *مركز مساعدة كويزلي*\n\n` +
          `يمكنك استخدام الأوامر التالية:\n` +
          `• /start - العودة للقائمة الرئيسية واختيار المشكلة\n` +
          `• /status - الاستعلام عن حالة تذاكرك الحالية\n` +
          `• /contact - فتح تذكرة دعم جديدة\n` +
          `• /help - عرض تعليمات استخدام البوت\n\n` +
          `للرد على المشرف، يمكنك كتابة رسالتك مباشرة هنا عند فتح التذكرة.`;

        await sendTelegramApi(
          'sendMessage',
          {
            chat_id: chatId,
            text: helpText,
            parse_mode: 'Markdown',
          },
          botToken
        );
        return res.status(200).send('OK');
      }

      // Check Command: /status (Phase 7)
      if (text === '/status') {
        let ticketsText = `📋 *تذاكر الدعم الخاصة بك:*\n\n`;
        try {
          const ticketsSnap = await db
            .collection('support_tickets')
            .where('telegramChatId', '==', chatId.toString())
            .orderBy('createdAt', 'desc')
            .limit(5)
            .get();

          if (ticketsSnap.empty) {
            ticketsText += `لا توجد لديك تذاكر دعم مسجلة حالياً.`;
          } else {
            ticketsSnap.docs.forEach((doc, idx) => {
              const data = doc.data();
              const statusBadge = data.status === 'resolved' ? '🟢 تم الحل' : '🟡 قيد الانتظار';
              ticketsText += `${idx + 1}. *تذكرة #${doc.id.slice(0, 6)}*\n`;
              ticketsText += `   فئة: ${data.category || 'عامة'}\n`;
              ticketsText += `   الحالة: ${statusBadge}\n`;
              ticketsText += `   الرسالة: ${data.message || ''}\n\n`;
            });
          }
        } catch (e) {
          console.error('Error fetching tickets for status command:', e);
          ticketsText += `حدث خطأ أثناء جلب التذاكر.`;
        }

        await sendTelegramApi(
          'sendMessage',
          {
            chat_id: chatId,
            text: ticketsText,
            parse_mode: 'Markdown',
          },
          botToken
        );
        return res.status(200).send('OK');
      }

      // Check Command: /contact (Phase 7)
      if (text === '/contact') {
        await sendTelegramApi(
          'sendMessage',
          {
            chat_id: chatId,
            text: `👋 يرجى اختيار نوع المشكلة أو الاستفسار لتسجيل تذكرة جديدة:`,
            reply_markup: buildCategoryKeyboard(),
          },
          botToken
        );
        return res.status(200).send('OK');
      }

      // Regular Message Handling -> Log support ticket (Phase 3 & 6)
      const sessionDoc = await db.collection('telegram_sessions').doc(chatId.toString()).get();
      const sessionData = sessionDoc.exists ? sessionDoc.data() : {};
      const category = sessionData.pendingCategory || 'مشكلة عامة';

      // Find user details if available
      let userId = sessionData.userId || null;
      let userName = sessionData.userName || telegramFullName;
      let userPhone = '';

      if (!userId) {
        // Try finding user linked by telegramChatId
        try {
          const uSnap = await db.collection('users').where('telegramChatId', '==', chatId.toString()).limit(1).get();
          if (!uSnap.empty) {
            const uDoc = uSnap.docs[0];
            userId = uDoc.id;
            const uData = uDoc.data();
            userName = uData.name || uData.fullName || telegramFullName;
            userPhone = uData.phone || uData.phoneNumber || '';
          }
        } catch (e) {
          console.error('Error checking user link:', e);
        }
      } else {
        try {
          const uDoc = await db.collection('users').doc(userId).get();
          if (uDoc.exists) {
            const uData = uDoc.data();
            userPhone = uData.phone || uData.phoneNumber || '';
          }
        } catch (e) {}
      }

      // Create Support Ticket in Firestore
      const newTicketRef = db.collection('support_tickets').doc();
      const ticketData = {
        id: newTicketRef.id,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        telegramChatId: chatId.toString(),
        telegramUsername: telegramUsername,
        category: category,
        message: text,
        status: 'open', // open | resolved
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        replies: [
          {
            sender: 'user',
            message: text,
            timestamp: new Date().toISOString(),
          },
        ],
      };

      await newTicketRef.set(ticketData);

      // Clear pending category session
      await db.collection('telegram_sessions').doc(chatId.toString()).set(
        {
          pendingCategory: null,
          lastTicketId: newTicketRef.id,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // Confirm to Telegram User
      const shortId = newTicketRef.id.slice(0, 6).toUpperCase();
      const responseMsg =
        `✅ *تم استلام تذكرتك وتأكيده بنجاح!*\n\n` +
        `🎫 *رقم التذكرة:* \`#${shortId}\`\n` +
        `📌 *الفئة:* ${category}\n` +
        `📝 *الرسالة:* ${text}\n\n` +
        `سيقوم فريق الدعم الفني بالرد عليك في أقرب وقت عبر هذا البوت 🎯`;

      await sendTelegramApi(
        'sendMessage',
        {
          chat_id: chatId,
          text: responseMsg,
          parse_mode: 'Markdown',
        },
        botToken
      );

      return res.status(200).send('OK');
    }

    return res.status(200).send('OK');
  } catch (err) {
    console.error('Fatal Webhook Error:', err);
    return res.status(500).send('Webhook processing error');
  }
};
