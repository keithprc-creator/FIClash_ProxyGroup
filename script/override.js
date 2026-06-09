// FlClash Script Override
// 在订阅配置基础上追加自定义代理组和规则，订阅更新后自动保持
// 使用方式：FlClash → 配置 → 覆写 → 脚本模式 → 粘贴此代码 → 保存

const main = (config) => {
  const allProxies = (config["proxies"] || []).map(p => p.name);

  // ─── Qoder 组 ─────────────────────────────────────────────
  // select 类型，DIRECT 默认，仅包含亚太节点可手动切换
  const qoderFilter = /(?:JP|TW|SG|HK)/i;
  const qoderProxies = ["DIRECT", ...allProxies.filter(n => qoderFilter.test(n))];

  // ─── OneDrive 组 ──────────────────────────────────────────
  // 外层 select 可手动切 DIRECT；内层 url-test 自动选延迟最低
  const onedriveAutoProxies = allProxies;

  // ─── LinkedIn 组 ──────────────────────────────────────────
  // 同 OneDrive 结构
  const linkedinAutoProxies = allProxies;

  // ─── 注入策略组（prepend 到订阅组之前）───────────────────
  config["proxy-groups"] = [
    {
      name: "Qoder",
      type: "select",
      proxies: qoderProxies
    },
    {
      name: "OneDrive",
      type: "select",
      proxies: ["OneDrive Auto", "DIRECT", ...allProxies]
    },
    {
      name: "OneDrive Auto",
      type: "url-test",
      proxies: onedriveAutoProxies,
      url: "http://www.gstatic.com/generate_204",
      interval: 180,
      tolerance: 50,
      hidden: true
    },
    {
      name: "LinkedIn",
      type: "select",
      proxies: ["LinkedIn Auto", "DIRECT", ...allProxies]
    },
    {
      name: "LinkedIn Auto",
      type: "url-test",
      proxies: linkedinAutoProxies,
      url: "http://www.gstatic.com/generate_204",
      interval: 180,
      tolerance: 50,
      hidden: true
    },
    ...config["proxy-groups"]
  ];

  // ─── 注入规则（prepend 到订阅规则之前）───────────────────
  config["rules"] = [
    // Qoder 进程匹配
    "PROCESS-NAME,Qoder,Qoder",
    "PROCESS-NAME,QoderWork,Qoder",
    "PROCESS-NAME,qodercli,Qoder",
    // OneDrive 域名
    "DOMAIN-SUFFIX,onedrive.com,OneDrive",
    "DOMAIN-SUFFIX,onedrive.live.com,OneDrive",
    "DOMAIN-SUFFIX,1drv.com,OneDrive",
    "DOMAIN-SUFFIX,1drv.ms,OneDrive",
    "DOMAIN-SUFFIX,sharepoint.com,OneDrive",
    "DOMAIN-SUFFIX,storage.live.com,OneDrive",
    "DOMAIN-KEYWORD,onedrive,OneDrive",
    // LinkedIn 域名
    "DOMAIN-SUFFIX,linkedin.com,LinkedIn",
    "DOMAIN-SUFFIX,licdn.com,LinkedIn",
    "DOMAIN-SUFFIX,linkedin.cn,LinkedIn",
    "DOMAIN-SUFFIX,lnkd.in,LinkedIn",
    "DOMAIN-KEYWORD,linkedin,LinkedIn",
    ...config["rules"]
  ];

  return config;
}
