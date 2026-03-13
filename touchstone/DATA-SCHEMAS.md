# Touchstone — JSON Data Schemas
## Every field tied to Craig's actual business

---

### dashboard.json
```json
{
  "greeting": "Good Morning, Craig",
  "date": "2026-03-13",
  "weather": { "temp": "-2°C", "condition": "partly cloudy", "roads": "clear", "wind": "15 km/h NW" },
  "stats": {
    "activeJobs": 24,
    "pipelineValue": 142000,
    "slabsInStock": 187,
    "usableRemnants": 34
  },
  "lastSync": "2026-03-13T10:00:00Z",
  "timestamp": "2026-03-13T10:00:00Z"
}
```

---

### schedule.json
```json
{
  "date": "2026-03-13",
  "installs": [
    {
      "id": "inst-001",
      "client": "Corey Bell",
      "company": "Lindsay's",
      "location": "Cole Harbour",
      "type": "Kitchen countertop install",
      "status": "confirmed",
      "crew": ["Jason"],
      "time": "08:00",
      "notes": "CEO of Lindsay's — earnout job"
    }
  ]
}
```

---

### messages.json
```json
{
  "summary": {
    "total": 360,
    "unread": 42,
    "tasksExtracted": 18,
    "followupsNeeded": 7
  },
  "messages": [
    {
      "id": "msg-001",
      "from": "Tyler",
      "initials": "TL",
      "color": "#0ea5e9",
      "timestamp": "2026-03-13T09:42:00Z",
      "text": "Hey Craig, got a quote request from the Hendersons — they want Calacatta for their kitchen island. Can you check slab availability?",
      "extractedTask": "Check Calacatta slab for Henderson",
      "tags": ["quote-request", "slab-check"],
      "jobRef": null,
      "followupRequired": true,
      "followupOwner": "Craig"
    },
    {
      "id": "msg-002",
      "from": "Jason",
      "initials": "JL",
      "color": "#4ade80",
      "timestamp": "2026-03-13T08:15:00Z",
      "text": "Supplier confirmed 4 slabs Statuario shipping Thursday. Delivery ETA next Tuesday.",
      "extractedTask": null,
      "tags": ["delivery-update"],
      "jobRef": null,
      "followupRequired": false
    },
    {
      "id": "msg-003",
      "from": "Shelley",
      "initials": "SH",
      "color": "#c084fc",
      "timestamp": "2026-03-13T07:50:00Z",
      "text": "Payment received from Cole Harbour — $4,200 e-transfer came through this morning.",
      "extractedTask": null,
      "tags": ["payment-received"],
      "jobRef": "proj-cole-harbour",
      "followupRequired": false
    }
  ]
}
```

---

### transcripts.json
```json
{
  "transcripts": [
    {
      "id": "tr-001",
      "title": "Tyler — Henderson Kitchen Discussion",
      "date": "2026-03-12",
      "duration": "12:34",
      "participants": ["Tyler", "Mr. Henderson"],
      "summary": "Henderson wants Calacatta for kitchen island. Budget ~$8K. Timeline: April install preferred.",
      "commitments": [
        { "who": "Tyler", "what": "Send Calacatta samples by Thursday", "dueDate": "2026-03-14" },
        { "who": "Tyler", "what": "Get slab pricing from supplier", "dueDate": "2026-03-13" }
      ],
      "dealValue": 8000,
      "tags": ["quote", "calacatta", "kitchen"]
    }
  ]
}
```

---

### tasks.json
```json
{
  "tasks": [
    {
      "id": "task-001",
      "title": "Follow up with Robbie Roberts — March 24-27 meeting",
      "source": "iMessage",
      "sourceRef": "msg-robbie-001",
      "assignee": "Craig",
      "status": "pending",
      "priority": "medium",
      "dueDate": "2026-03-20",
      "context": "Robbie wants granite remnants for barbecue prep station. Craig said yes but 'might be heading to Florida.' Still in limbo.",
      "tags": ["follow-up", "remnant", "customer"]
    },
    {
      "id": "task-002",
      "title": "Check airport invoice — was it ever sent?",
      "source": "leakage-detection",
      "assignee": "Lenore",
      "status": "urgent",
      "priority": "high",
      "context": "Airport wants another job. Need to check if last job was invoiced. Previously found it wasn't billed at all.",
      "tags": ["invoice", "leakage"]
    }
  ]
}
```

---

### projects.json
```json
{
  "projects": [
    {
      "id": "proj-001",
      "client": "Corey Bell",
      "company": "Lindsay's",
      "description": "Kitchen countertop",
      "entity": "Livingstone",
      "status": "in-progress",
      "progress": 70,
      "checklist": {
        "estimateReceived": true,
        "drawingsReviewed": true,
        "materialOrdered": true,
        "drawingsEmailed": true,
        "sinkNeeded": true,
        "sinkOrdered": false,
        "auditOpened": true,
        "fabricationStarted": false,
        "installed": false,
        "invoiced": false,
        "paid": false
      },
      "financials": {
        "quoteAmount": 8400,
        "materialCost": 3200,
        "fabricationCost": 1800,
        "targetMargin": 0.40,
        "actualMargin": null
      },
      "notes": "Estimate files not yet available — need to get these for this guy"
    }
  ]
}
```

---

### audit.json
```json
{
  "livingstone": {
    "currentYearRates": { "year": 2026, "fabricationRate": 80, "installRate": 65 },
    "earnout": {
      "yearTarget": 480000,
      "yearToDate": 412000,
      "clientRetention": 0.94,
      "nextReview": "2026-04-15"
    }
  },
  "audits": [
    {
      "id": "audit-001",
      "projectId": "proj-001",
      "client": "Corey Bell",
      "entity": "Livingstone",
      "shelleyCalc": {
        "productionSqFt": 42.5,
        "materialCost": 3200,
        "fabricationCost": 1800,
        "grossProfit": 3400,
        "lsShare": 1800,
        "compassShare": 1600
      },
      "livingstoneCalc": {
        "materialCost": 3200,
        "fabricationCost": 1925,
        "grossProfit": 3275
      },
      "discrepancy": 125,
      "discrepancyStatus": "reviewing",
      "remnant": {
        "expectedRemnant": "26\" × 48\" usable piece",
        "remnantValue": 840,
        "creditApplied": false
      },
      "invoiceStatus": "pending",
      "invoiceModified": false,
      "notes": ""
    }
  ],
  "alerts": [
    {
      "type": "discrepancy",
      "message": "INV-1042: $2,800 discrepancy — materials billed but not received",
      "severity": "critical"
    },
    {
      "type": "modification",
      "message": "INV-1038: $162 post-payment modification — needs approval",
      "severity": "warning"
    },
    {
      "type": "credit",
      "message": "INV-1029: $799 remnant credit not applied",
      "severity": "warning"
    }
  ]
}
```

---

### pipeline.json
```json
{
  "stats": {
    "winRate": 0.68,
    "pipelineValue": 142000,
    "avgDealSize": 5200,
    "activeQuotes": 12
  },
  "deals": [
    {
      "id": "deal-001",
      "client": "Robbie Roberts",
      "description": "Granite remnants — barbecue prep station",
      "value": 2400,
      "status": "follow-up",
      "owner": "Craig",
      "lastContact": "2026-03-10",
      "nextAction": "Confirm March 24-27 availability",
      "sampleSent": false,
      "flooringOpportunity": false,
      "staledays": 3
    }
  ],
  "samples": {
    "out": 3,
    "overdue": 2,
    "returned": 1
  },
  "reactivation": {
    "upgradeCandidates": 142,
    "upsellOpportunities": 89,
    "reengageTargets": 34
  }
}
```

---

### invoices.json
```json
{
  "summary": {
    "totalReceivables": 42000,
    "overdue": 8200,
    "unbilled": 4200,
    "leakageAlerts": 3
  },
  "aging": {
    "days0to30": 12400,
    "days31to60": 6200,
    "days61to90": 7400
  },
  "cashFlow": [
    { "month": "Jan", "actual": 92000 },
    { "month": "Feb", "actual": 104000 },
    { "month": "Mar", "actual": 118000 },
    { "month": "Apr", "projected": 112000 },
    { "month": "May", "projected": 126000 }
  ],
  "revenueBreakdown": {
    "residential": 0.60,
    "commercial": 0.20,
    "contractor": 0.20
  },
  "leakageAlerts": [
    {
      "type": "unbilled",
      "job": "Airport Lounge",
      "amount": 3200,
      "description": "Job completed, invoice never sent",
      "severity": "critical",
      "discoveredBy": "Lenore"
    },
    {
      "type": "partial",
      "job": "Bedford project",
      "amount": 2800,
      "description": "Invoice shows 5 hours, should be 40 hours at $80/hr",
      "severity": "critical",
      "discoveredBy": "Lenore"
    }
  ],
  "livingstoneModifications": [
    {
      "invoiceId": "LS-NOV-042",
      "originalAmount": 2200,
      "modifiedAmount": 2650,
      "addedItem": "Bosco sink",
      "dateModified": "2026-01-15",
      "status": "disputed"
    }
  ],
  "quickbooksSync": {
    "connected": false,
    "lastSync": null,
    "status": "pending-setup"
  }
}
```

---

### fabrication.json
```json
{
  "pipeline": [
    {
      "id": "fab-001",
      "projectId": "proj-001",
      "client": "Corey Bell",
      "stage": "slab-layout",
      "stages": {
        "drawingReceived": { "done": true, "date": "2026-03-10" },
        "shelleyReview": { "done": true, "date": "2026-03-11" },
        "slabCalc": { "done": true, "date": "2026-03-11" },
        "remnantCalc": { "done": true, "date": "2026-03-11" },
        "costCalc": { "done": true, "date": "2026-03-11" },
        "auditEntry": { "done": true, "date": "2026-03-11" },
        "materialOrdered": { "done": false },
        "fabrication": { "done": false },
        "install": { "done": false }
      },
      "drawing": {
        "type": "2D",
        "shape": "L-shape kitchen",
        "sqFt": 42.5
      },
      "slabs": {
        "product": "Luna",
        "pricePerSheet": 1250,
        "sheetsNeeded": 2,
        "seamPlacement": "island-to-peninsula joint",
        "totalMaterialCost": 2500
      },
      "remnant": {
        "totalWaste": "8.2 sq ft",
        "usablePieces": [
          { "width": 26, "length": 48, "value": 840, "inInventory": false }
        ],
        "nonUsableWaste": "2.1 sq ft",
        "creditAmount": 840
      },
      "cost": {
        "material": 2500,
        "fabrication": 1800,
        "wasteCost": 0,
        "remnantCredit": -840,
        "totalJobCost": 3460,
        "quotePrice": 8400,
        "grossProfit": 4940,
        "margin": 0.588
      }
    }
  ]
}
```

---

### inventory.json
```json
{
  "slabs": {
    "total": 187,
    "lowStock": 7,
    "items": [
      {
        "product": "Luna",
        "quantity": 12,
        "pricePerSheet": 1250,
        "dimensions": "120\" × 56\"",
        "lowStockThreshold": 5,
        "isLowStock": false
      },
      {
        "product": "Caesarstone Empira White",
        "quantity": 4,
        "pricePerSheet": 1650,
        "dimensions": "120\" × 56\"",
        "lowStockThreshold": 5,
        "isLowStock": true
      }
    ]
  },
  "remnants": {
    "total": 34,
    "totalValue": 12000,
    "items": [
      {
        "id": "rem-001",
        "product": "Bianco Romano",
        "width": 26,
        "length": 48,
        "value": 840,
        "location": "Bay 3, Rack 2",
        "usable": true
      }
    ]
  }
}
```

---

### flooring.json
```json
{
  "clientMining": {
    "totalClients": 7500,
    "segmented": {
      "developers": 0,
      "multiProject": 0,
      "referralCandidates": 0,
      "flooringProspects": 0
    },
    "status": "pending-crm-access"
  },
  "outreach": {
    "campaignsSent": 0,
    "responses": 0,
    "quotesGenerated": 0
  },
  "quotes": [],
  "suppliers": {
    "tega": { "name": "Tega", "distance": "5 min", "products": "Luxury vinyl plank" },
    "goodfellow": { "name": "Goodfellow", "products": "Luxury vinyl plank" }
  },
  "deliveries": []
}
```

---

### followups.json
```json
{
  "stale": [
    {
      "id": "fu-001",
      "person": "Robbie Roberts",
      "owner": "Craig",
      "type": "customer",
      "lastContact": "2026-03-10",
      "staleDays": 3,
      "context": "Wants granite remnants for barbecue prep station, March 24-27. Craig said yes but Florida trip uncertain.",
      "action": "Confirm availability for March 24-27"
    }
  ],
  "pending": [],
  "expiringQuotes": []
}
```

---

### receipts.json, documents.json, agents.json, security.json, meetings.json, team.json
Standard schemas — same as existing SolveWorks dashboards.

### team.json
```json
{
  "members": [
    { "name": "Craig Lucas", "initials": "CL", "role": "Owner", "color": "#0ea5e9" },
    { "name": "Tyler", "initials": "TL", "role": "Sales", "color": "#60a5fa" },
    { "name": "Shelley", "initials": "SH", "role": "Estimating & Audit", "color": "#c084fc" },
    { "name": "Lenore", "initials": "LN", "role": "CRM & Admin", "color": "#4ade80" },
    { "name": "Jason", "initials": "JL", "role": "Installer", "color": "#fbbf24" }
  ]
}
```
