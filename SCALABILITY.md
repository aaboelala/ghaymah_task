# 🚀 قابلية التوسع وتوزيع الأحمال على منصة غيمة (Scalability & Load Balancing)

---

## 1️⃣ المخطط الهندسي للنظام (Architecture Diagram — 15,000 req/s)

تم تصميم المعمارية التالية للاستجابة لـ **15,000 طلب في الثانية (15,000 req/s)** مع توافر عالي (High Availability) وأداء متفوق على منصة غيمة:

```mermaid
flowchart TD
    subgraph Clients["🌐 المستخدمون والتطبيقات"]
        U1["📱 Mobile Apps"]
        U2["💻 Web Browsers"]
    end

    subgraph EdgeLayer["⚡ Ghaymah Edge Layer"]
        CDN["Ghaymah Global CDN & DDoS Protection"]
        DNS["Ghaymah Anycast DNS"]
    end

    subgraph LBLayer["🔀 Ghaymah Load Balancing Tier"]
        ALB1["Ghaymah Application Load Balancer (Primary)"]
        ALB2["Ghaymah Application Load Balancer (Backup)"]
    end

    subgraph AppCluster["📦 Ghaymah Compute (Stateless Application Cluster)"]
        direction TB
        subgraph PodGroup1["Zone A (13 Replicas)"]
            P1["App Pod 1..13"]
        end
        subgraph PodGroup2["Zone B (13 Replicas)"]
            P2["App Pod 14..26"]
        end
        subgraph PodGroup3["Zone C (13 Replicas)"]
            P3["App Pod 27..39"]
        end
    end

    subgraph CacheDB["💾 Caching & Database Tier"]
        Redis["Ghaymah In-Memory Redis Cache"]
        DBPrimary[("PostgreSQL Primary (Write)")]
        DBReplica[("PostgreSQL Replica (Read)")]
    end

    subgraph StorageLayer["📁 Ghaymah Stateful Storage"]
        GBS[("Ghaymah Block Storage (NVMe SSD)")]
    end

    U1 & U2 --> DNS --> CDN
    CDN --> ALB1 & ALB2
    ALB1 & ALB2 -->|Round-Robin / Least Connections| PodGroup1 & PodGroup2 & PodGroup3
    
    PodGroup1 & PodGroup2 & PodGroup3 -->|Cache Lookups| Redis
    PodGroup1 & PodGroup2 & PodGroup3 -->|Write Ops| DBPrimary
    PodGroup1 & PodGroup2 & PodGroup3 -->|Read Ops| DBReplica

    DBPrimary & DBReplica <-->|Persistent Volume Claim (PVC)| GBS
```

---

## 2️⃣ حساب عدد الحاويات المطلوبة (Capacity Planning & Sizing)

### 📊 المعطيات:
* **حركة المرور المستهدفة (Target Traffic):** $15,000 \text{ req/s}$
* **طاقة الحاوية الواحدة (Container Capacity):** $500 \text{ req/s}$
* **هامش الأمان الموصى به (Safety Margin Buffer):** $30\%$

---

### 🧮 الخطوات الحسابية:

1. **حساب إجمالي حركة المرور المطلوبة مع هامش الأمان:**
   $$\text{Total Traffic with Buffer} = 15,000 \times (1 + 0.30) = 15,000 \times 1.30 = 19,500 \text{ req/s}$$

2. **حساب عدد الحاويات المطلوبة:**
   $$\text{Number of Containers} = \left\lceil \frac{19,500 \text{ req/s}}{500 \text{ req/s}} \right\rceil = 39 \text{ Containers}$$

---

### 📌 النتيجة والتوزيع على بيئات غيمة:
* **إجمالي عدد الحاويات (Pods):** **39 حاوية** (تضمن معالجة $19,500 \text{ req/s}$ بكفاءة عالية وبدون اختناق).
* **توزيع الحاويات على مناطق التوافر (Multi-AZ Deployment):**
  * **Zone A:** 13 Pods
  * **Zone B:** 13 Pods
  * **Zone C:** 13 Pods
* **سبب إضافة هامش الأمان (30% Buffer):**
  1. امتصاص الارتفاعات المفاجئة واللحظية في حركة المرور (Traffic Spikes).
  2. تغطية استهلاك الموارد الموجه لـ Health Checks و Garbage Collection.
  3. حماية النظام أثناء إعادة تشغيل الحاويات أو تحديثات النسخ (Rolling Updates).

---

## 3️⃣ استراتيجية تقليل الـ Cold Start للحاويات الجديدة

الـ **Cold Start** هو الوقت المستغرق بين إطلاق حاوية جديدة وجاهزيتها التامة لاستقبال الطلبات. لتقليل هذا الوقت لأقل من 1 ثانية في منصة غيمة، نتبع الاستراتيجيات التالية:

### 1. تصغير حجم صورة الحاوية (Lightweight Docker Images)
* استخدام صور **Multi-stage Build** مبنية على `scratch` أو `alpine` (حجم الصورة النهائي **~6.7 ميجابايت** كما تم بناؤه في Dockerfile غيمة).
* الصورة الصغيرة يسهل سحبها من **Ghaymah Container Registry** عبر شبكة غيمة السريعة خلال مسبارات زمنية تقل عن **200ms**.

### 2. التوسع الاستباقي (Proactive Pre-Warming & Buffer Capacity)
* ضبط الحد الأدنى للحاويات عند 39 حاوية، وتفعيل التوسع التلقائي (HPA) فور وصول استهلاك الذاكرة أو المعالج إلى **70%** (بدلاً من 90%).
* هذا يمنح الـ Clusters وقتاً كافياً لإطلاق الحاويات قبل وصول الضغط الفعلي للذروة.

### 3. تحسين فحوصات الجاهزية (Readiness Probes Tuning)
* ضبط فحوصات الجاهزية للبدء سريعاً بدون تأخير غير برمجيات:
  ```yaml
  readinessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 1  # البدء بالفحص فوراً بعد ثانية واحدة
    periodSeconds: 2        # الفحص كل ثانيتين
    successThreshold: 1
    failureThreshold: 2
  ```

### 4. تسريع وقت تشغيل التطبيق (Fast Application Startup)
* الاعتماد على لغة Go المجمعة بلغة الآلة (Native Compiled Output) والتي تبدأ العمل خلال أجزاء من الملي ثانية بدون تجمعات JVM أو حزم تفسير ثقيلة.
* تجميع وإيقاف أي اتصالات قاعدة بيانات كسولة (Lazy Initialization) واستبدالها باتصالات جاهزة سلفاً (Pre-warmed connection pools).

---

## 4️⃣ استخدام Ghaymah Block Storage للبيانات المستمرة (Stateful Workloads)

تعتمد الحاويات بطبيعتها على كونها **Stateless** (تزول بياناتها بزوال الحاوية). ولتشغيل التطبيقات التي تتطلب حفظ البيانات بشكل دائم (Stateful Workloads مثل قواعد البيانات PostgreSQL و Redis Persistent Logs)، توفر منصة غيمة **Ghaymah Block Storage (GBS)**.

### 🔑 أهم الميزات والية العمل:

```text
┌────────────────────────┐        Persistent Volume Claim        ┌────────────────────────────┐
│   PostgreSQL Pod       │ ───────────────────────────────────► │ Ghaymah Block Storage (PV) │
│ (Stateful Workload)    │       (Attach NVMe Storage)        │   (High-Performance SSD)   │
└────────────────────────┘                                     └────────────────────────────┘
```

1. **الأداء العالي (High Performance NVMe Volumes):**
   * يوفر Ghaymah Block Storage أقراص NVMe فائقة السرعة مع معدل عمليات إدخال/إخراج يصل إلى **60,000 IOPS** وتأخير أقل من **1ms**، وهو مثالي لقواعد البيانات الضخمة.

2. **التكامل عبر Kubernetes Dynamic Provisioning (PVC & StorageClass):**
   * يتم ربط التخزين بالتطبيقات باستخدام `PersistentVolumeClaim` (PVC) وتحديد `StorageClass: ghaymah-block-nvme`:
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: ghaymah-db-pvc
   spec:
     accessModes:
       - ReadWriteOnce
     storageClassName: ghaymah-block-nvme
     resources:
       requests:
         storage: 250Gi
   ```

3. **الحماية والاستمرارية (Data Persistence & High Availability):**
   * عند تعطل الـ Pod المربوط بوحدة التخزين، تقوم منصة غيمة تلقائياً بفصل قرص الـ Block Storage وإعادة ربطه (`Attach/Detach`) بالـ Pod الجديد عبر عقدة أخرى بدون أي فقدان للبيانات.

4. **النسخ الاحتياطي واللقطات الفورية (Snapshots & Replication):**
   * يدعم Ghaymah Block Storage إنشاء لقطات فورية (Volume Snapshots) دورية بدون التأثير على أداء الخدمة الحية، مع إمكانية استرجاعها فوراً في حالات الطوارئ (Disaster Recovery).
