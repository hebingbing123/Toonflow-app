//! WebSocket 通知中心。
//!
//! 服务器发起的 WebSocket 文本帧扇出到认证用户（如任务状态更新）。

use std::collections::HashMap;
use std::sync::Arc;

use tokio::sync::{mpsc::UnboundedSender, RwLock};
use uuid::Uuid;

type UserSockets = HashMap<Uuid, Vec<(Uuid, UnboundedSender<String>)>>;

#[derive(Clone)]
pub struct WsNotifyHub {
    inner: Arc<RwLock<UserSockets>>,
}

impl WsNotifyHub {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(RwLock::new(UserSockets::new())),
        }
    }

    /// Returns a connection id used with [`Self::unsubscribe`].
    pub async fn subscribe(&self, user_id: Uuid, tx: UnboundedSender<String>) -> Uuid {
        let conn_id = Uuid::new_v4();
        let mut g = self.inner.write().await;
        g.entry(user_id).or_default().push((conn_id, tx));
        conn_id
    }

    pub async fn unsubscribe(&self, user_id: Uuid, conn_id: Uuid) {
        let mut g = self.inner.write().await;
        if let Some(v) = g.get_mut(&user_id) {
            v.retain(|(id, _)| *id != conn_id);
            if v.is_empty() {
                g.remove(&user_id);
            }
        }
    }

    /// Drops dead senders automatically.
    pub async fn broadcast_to_user(&self, user_id: Uuid, text: String) {
        let mut g = self.inner.write().await;
        let Some(senders) = g.get_mut(&user_id) else {
            return;
        };
        senders.retain(|(_, tx)| tx.send(text.clone()).is_ok());
        if senders.is_empty() {
            g.remove(&user_id);
        }
    }
}
