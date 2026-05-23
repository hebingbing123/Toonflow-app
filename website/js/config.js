/**
 * 部署时按需修改：Web 版应用地址、文档与商务联系入口。
 * OpenFlow 为商业授权产品，宣传页链接默认指向站内锚点，勿指向公开源码仓库。
 */
window.OpenFlowSiteConfig = {
  appUrl: "",
  /** 文档与手册：随授权交付；未配置时滚动到本站 #docs */
  docsUrl: "#docs",
  docsEnUrl: "#docs",
  userManualUrl: "#docs",
  userManualEnUrl: "#docs",
  userGuideUrl: "#docs",
  userGuideEnUrl: "#docs",
  /** 商务联系 / 试用申请 */
  contactUrl: "#contact",
  gettingStartedUrl: "#contact",
  gettingStartedEnUrl: "#contact",
  operatorsUrl: "#contact",
  operatorsEnUrl: "#contact",
  gettingStartedIndexUrl: "#docs",
  /** 客户端安装包由商务发放，非公开下载页 */
  releasesUrl: "#contact",
  repoUrl: "",
  demoVideoUrl: "",
  /** 产品预览轮播 — 从设计稿拼板裁剪（见 scripts/crop-website-assets.sh） */
  demoSlides: [
    { src: "assets/screenshots/hero-main.png", captionKey: "demo.caption.hero" },
    { src: "assets/screenshots/desktop-studio.png", captionKey: "demo.caption.desktop" },
    { src: "assets/screenshots/web-app.png", captionKey: "demo.caption.web" },
    { src: "assets/screenshots/mobile-app.png", captionKey: "demo.caption.mobile" },
    { src: "assets/screenshots/mobile-02-script.png", captionKey: "demo.caption.script" },
    { src: "assets/screenshots/mobile-03-storyboard.png", captionKey: "demo.caption.storyboard" },
    { src: "assets/screenshots/features-trio.png", captionKey: "demo.caption.features" },
  ],
};
