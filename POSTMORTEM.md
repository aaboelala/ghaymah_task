# 📋 تقرير تحليل حادثة انقطاع الخدمة — Postmortem Report

---

## 1️⃣ تقرير الـ Postmortem التفصيلي

### 📑 الملخص التنفيذي (Executive Summary)
* **اسم الحادثة:** INC-2026-0728-OOM
* **تاريخ الحادثة:** 28 يوليو 2026
* **مدة الانقطاع (Downtime):** 45 دقيقة (10:00 - 10:45 UTC)
* **مستوى الأهمية (Severity):** Critical (SEV-1)
* **السبب الرئيسي:** حدوث حالات `OOMKilled` (Out Of Memory) متكررة للحاويات نتيجة ارتفاع مفاجئ في حركة المرور (Traffic Spike) مع عدم وجود سياسة للتوسع التلقائي (Auto-scaling) وضيق حدود الذاكرة المخصصة.
* **الأثر على الخدمة:** توقف تام لأحد الخدمات الأساسية (HTTP 502 Bad Gateway) وتضرر 100% من طلبات المستخدمين أثناء فترة الانقطاع.

---

### ⏱️ الجدول الزمني للحادثة (Timeline of Events)

| الوقت (UTC) | الحدث |
| :--- | :--- |
| **10:00** | بدء ارتفاع مفاجئ في عدد الطلبات الموجهة للخدمة (تضاعف عدد الطلبات 5 مرات). |
| **10:05** | تجاوز استهلاك الذاكرة الحد الأقصى المخصص (`Memory Limit = 512MiB`)، وقام الـ Linux Kernel بإنهاء الحاوية (`OOMKilled - Exit Code 137`). |
| **10:08** | دخول الحاوية في حالة `CrashLoopBackOff` بسبب تكرار الـ OOM فور إعادة التشغيل. |
| **10:12** | انطلاق أول تنبيه (Health Check Failure) وفشلت فحوصات الجاهزية (Liveness & Readiness Probes). |
| **10:20** | استجابة فريق الـ SRE وبدء التحقيق في المشكلة عبر مراجعة السجلات والتنبيهات. |
| **10:30** | تحديد السبب الجذر: حدوث `OOMKilled` متكرر لجميع الـ Replicas الشغالة. |
| **10:38** | **إجراء طارئ:** رفع حدود الذاكرة يدويًا من `512MiB` إلى `2GiB` وزيادة عدد الـ Pods من 2 إلى 6. |
| **10:45** | استقرار جميع الحاويات، وعودة مؤشرات الخدمة إلى الوضع الطبيعي (HTTP 200 OK) وانتهاء الحادثة. |

---

### 🔍 السبب الجذر (Root Cause Analysis - RCA)

1. **قصور في تخصيص الموارد (Insufficient Memory Limits):**
   * تم تخصيص حد ذاكرة منخفض جِدًّا (`512MiB`) لا يتناسب مع حجم العمل المرتفع، مما جعل التطبيق عرضة للإنهاء المباشر بواسطة الـ OOM Killer عند حدوث ضغط.
2. **غياب التوسع التلقائي (No Auto-scaling):**
   * لم يتم إعداد `HorizontalPodAutoscaler` (HPA) للتوسع الأفقي عند ارتفاع الضغط.
3. **تنبيهات متأخرة للذاكرة:**
   * التنبيهات كانت مجهزة فقط عند توقف الخدمة تمامًا (`Health Check Failed`) بدلاً من التنبيه المبكر عند وصول استهلاك الذاكرة إلى 80%.

---

### 🛠️ التوصيات والإجراءات التصحيحية (Action Items)

| الرقم | الإجراء (Action Item) | النوع | الأولوية |
| :---: | :--- | :---: | :---: |
| **1** | زيادة الـ Memory Limits الأساسية من `512MiB` إلى `1GiB` وتحديد `Requests` عند `512MiB`. | فوري (Immediate) | 🔴 P0 |
| **2** | تطبيق سياسة Auto-scaling أفقية (HPA) لمنصة غيمة تعمل على الذاكرة والـ CPU. | متوسط (Medium) | 🔴 P0 |
| **3** | إضافة قواعد تنبيه مبكرة عند تجاوز الذاكرة نسبة 80% وقبل الوصول لـ 100%. | فوري (Immediate) | 🟡 P1 |
| **4** | إجبار إجراء اختبارات ضغط (Load & Stress Testing) قبل الترقية للإنتاج. | طويل المدى | 🟢 P2 |

---

## 2️⃣ تصميم سياسة Auto-scaling لمنصة غيمة (Ghaymah Auto-scaling Policy)

لتفادي تكرار حادثة `OOMKilled` مستقبلاً، تم تصميم سياسة **Horizontal Pod Autoscaler (HPA)** مخصصة لمنصة غيمة:

### 📐 المكونات والحدود (Policy Configuration)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ghaymah-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ghaymah-sre-api
  minReplicas: 3          # الحد الأدنى لضمان العزل والتوافر العالي
  maxReplicas: 15         # الحد الأقصى للاستجابة للهجمات أو الضغط العالي
  metrics:
    # 1. التوسع بناءً على الذاكرة (Memory Utilization) - منع الـ OOM
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70  # التوسع فور وصول الذاكرة إلى 70%
    # 2. التوسع بناءً على المعالج (CPU Utilization)
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 75
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0 # توسع فوري (0 ثانية) لتجنب OOMKilled
      policies:
        - type: Percent
          value: 100               # مضاعفة عدد الـ Pods فوراً عند الضغط
          periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300 # الانتظار 5 دقائق قبل تقليص العدد لمنع Flapping
```

### 💡 قواعد الموارد في الحاوية (Resource Requests & Limits)
```yaml
resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "1024Mi"
```

---

## 3️⃣ الكشف المبكر والمراقبة باستخدام أدوات غيمة (Early Detection & Observability)

لكشف مشكلة الذاكرة قبل وصولها لمرحلة `OOMKilled`:

### 1. إعداد قواعد التنبيه المبكر (Prometheus Alert Rules)

* **تنبيه تحذيري لارتفاع الذاكرة (Memory Usage Warning > 80%):**
  ```yaml
  alert: HighMemoryUsageWarning
  expr: (container_memory_working_set_bytes{container!=""} / container_spec_memory_limit_bytes{container!=""}) * 100 > 80
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "استهلاك الذاكرة تجاوز 80% في الحاوية {{ $labels.pod }}"
  ```

* **تنبيه عاجل لحدث OOMKilled أو إعادة تشغيل متكررة:**
  ```yaml
  alert: ContainerOOMKilledDetected
  expr: increase(kube_pod_container_status_restarts_total[5m]) > 2
  for: 0m
  labels:
    severity: critical
  annotations:
    summary: "تم اكتشاف إعادة تشغيل متكررة للحاوية {{ $labels.pod }} - احتمال OOMKilled"
  ```

---

### 2. أهم المؤشرات في لوحة المراقبة (Dashboard Metrics)

1. **`container_memory_working_set_bytes`**: قياس حجم الذاكرة المستخدمة فعلياً مقارنة بالحد الأقصى (`container_spec_memory_limit_bytes`).
2. **`kube_pod_container_status_last_terminated_reason`**: الكشف الفوري عن قيمة `OOMKilled`.
3. **`rate(http_requests_total[1m])`**: متابعة نمو الطلبات للتنبؤ بالضغط والتوسع المبكر.
