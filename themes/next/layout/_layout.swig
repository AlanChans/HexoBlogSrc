<!DOCTYPE html>
<html lang="{{ config.language }}">
<head>
  {{ partial('_partials/head/head.swig', {}, {cache: theme.cache.enable}) }}
  {% include '_partials/head/head-unique.swig' %}
  {{- next_inject('head') }}
  <title>{% block title %}{% endblock %}</title>
  {{ partial('_third-party/analytics/index.swig', {}, {cache: theme.cache.enable}) }}
  {{ partial('_scripts/noscript.swig', {}, {cache: theme.cache.enable}) }}

  <!-- 指定jquery源-->
  <script type="text/javascript" 
  src="//code.jquery.com/jquery-1.11.0.js"></script>
  <script type="text/javascript" 
  src="//code.jquery.com/jquery-1.11.0.min.js"></script>
  <!--pjax：防止跳转页面音乐暂停-->
  <script src="https://cdn.jsdelivr.net/npm/pjax@0.2.8/pjax.js"></script> 
  <!--浏览器搞笑标题-->
  <script type="text/javascript" src="/js/FunnyTitle.js"></script>
  
  <!-- 雪花特效 -->
  <script type="text/javascript" src="/js/snow.js"></script>
  <!-- 数字雨 -->
  <canvas id="canvas" width="1440" height="900" ></canvas>
  <script type="text/javascript" src="/js/DigitalRain.js"></script>

</head>

<body itemscope itemtype="http://schema.org/WebPage">
  <div class="container{%- if theme.motion.enable %} use-motion{%- endif %}">
    <div class="headband"></div>

    <header class="header" itemscope itemtype="http://schema.org/WPHeader">
      <div class="header-inner">{% include '_partials/header/index.swig' %}</div>
    </header>
    {{ partial('_partials/widgets.swig', {}, {cache: theme.cache.enable}) }}

    <main class="main">
      <div class="main-inner">
        <div class="content-wrap">
                <!-- 彩色滚动变换字体-->
        <div id="binft">
        </div>
        <script>
          var binft = function (r) {
            function t() {
              return b[Math.floor(Math.random() * b.length)]
            }  
            function e() {
              return String.fromCharCode(94 * Math.random() + 33)
            }
            function n(r) {
              for (var n = document.createDocumentFragment(), i = 0; r > i; i++) {
                var l = document.createElement("span");
                l.textContent = e(), l.style.color = t(), n.appendChild(l)
              }
              return n
            }
            function i() {
              var t = o[c.skillI];
              c.step ? c.step-- : (c.step = g, c.prefixP < l.length ? (c.prefixP >= 0 && (c.text += l[c.prefixP]), c.prefixP++) : "forward" === c.direction ? c.skillP < t.length ? (c.text += t[c.skillP], c.skillP++) : c.delay ? c.delay-- : (c.direction = "backward", c.delay = a) : c.skillP > 0 ? (c.text = c.text.slice(0, -1), c.skillP--) : (c.skillI = (c.skillI + 1) % o.length, c.direction = "forward")), r.textContent = c.text, r.appendChild(n(c.prefixP < l.length ? Math.min(s, s + c.prefixP) : Math.min(s, t.length - c.skillP))), setTimeout(i, d)
            }
            var l = "",
            o = ["青青陵上柏，磊磊涧中石。", "人生天地间，忽如远行客。","斗酒相娱乐，聊厚不为薄。", "驱车策驽马，游戏宛与洛。","洛中何郁郁，冠带自相索。","长衢罗夹巷，王侯多第宅。","两宫遥相望，双阙百余尺。","极宴娱心意，戚戚何所迫？", "我拜唐僧入佛门，不爱娇娥悟红尘。春风何能空拂柳，南海幽蓝净瓶中。","半生风雨半身寒，一杯浊酒敬流年，回首过往半生路，七分酸楚三分甜，日出东方催人醒，不及晚霞懂我心，辞别再无相见日，终是一人渡春秋！","尚未佩妥剑,转眼便江湖。愿历尽千帆,归来仍少年", "我曾见过群山万重，后见你眉眼,便觉山河少了一抹春色。说起来虽然夸张,但我仍然觉得,你的眼里最适合淌着星河。", "我听过最善良的一句话是:“你在路上碰到的一个路人,都是别人做梦都想见到的人。”"].map(function (r) {
            return r + ""
            }),
            a = 2,
            g = 1,
            s = 5,
            d = 75,
            b = ["rgb(110,64,170)", "rgb(150,61,179)", "rgb(191,60,175)", "rgb(228,65,157)", "rgb(254,75,131)", "rgb(255,94,99)", "rgb(255,120,71)", "rgb(251,150,51)", "rgb(226,183,47)", "rgb(198,214,60)", "rgb(175,240,91)", "rgb(127,246,88)", "rgb(82,246,103)", "rgb(48,239,130)", "rgb(29,223,163)", "rgb(26,199,194)", "rgb(35,171,216)", "rgb(54,140,225)", "rgb(76,110,219)", "rgb(96,84,200)"],
            c = {
              text: "",
              prefixP: -s,
              skillI: 0,
              skillP: 0,
              direction: "forward",
              delay: a,
              step: g
            };
            i()
            };
            binft(document.getElementById('binft'));
        </script>
          {% include '_partials/header/sub-menu.swig' %}
          <div class="content {% block class %}{% endblock %}">
            {% block content %}{% endblock %}
          </div>
          {% include '_partials/comments.swig' %}
        </div>
        {%- if theme.sidebar.display !== 'remove' %}
          {% block sidebar %}{% endblock %}
        {%- endif %}
      </div>
    </main>

    <footer class="footer">
      <div class="footer-inner">
        {% include '_partials/languages.swig' %}
        {{ partial('_partials/footer.swig', {}, {cache: theme.cache.enable}) }}
        {{ partial('_third-party/statistics/index.swig', {}, {cache: theme.cache.enable}) }}
      </div>
    </footer>
  </div>

  {{ partial('_scripts/index.swig', {}, {cache: theme.cache.enable}) }}
  {{ partial('_third-party/index.swig', {}, {cache: theme.cache.enable}) }}

  {%- if theme.pjax %}
    <div id="pjax">
  {%- endif %}
  {% include '_third-party/math/index.swig' %}
  {% include '_third-party/quicklink.swig' %}

  {{- next_inject('bodyEnd') }}
  {%- if theme.pjax %}
    </div>
  {%- endif %}

  {% if theme.fireworks %}
   <canvas class="fireworks" style="position: fixed;left: 0;top: 0;z-index: 1; pointer-events: none;" ></canvas> 
   <script type="text/javascript" src="//cdn.bootcss.com/animejs/2.2.0/anime.min.js"></script> 
   <script type="text/javascript" src="/js/src/fireworks.js"></script>
  {% endif %}

  {% if theme.clickshowtext %}
  <!--单击显示文字-->
  <script type="text/javascript" src="/js/click_show_text.js"></script>
  {% endif %}

</body>
</html>
