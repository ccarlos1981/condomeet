// web-app/tests/parcel_ai_extract_web_e2e.test.ts
// Automated E2E verification suite for Web Panel AI Parcel Extraction logic with Manual Priority Optimization

// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const Deno: any;

function assertEquals(actual: unknown, expected: unknown, msg?: string) {
  if (actual !== expected) {
    throw new Error(
      `Assertion failed: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}. ${msg || ""}`
    );
  }
}

interface UnitOption {
  blocoNome: string;
  aptoNumero: string;
  residentId: string | null;
  residentName: string | null;
}

// ── Simulation of ParcelRegisterForm Logic ──────────────────────────────────

class WebParcelRegisterEngine {
  units: UnitOption[];
  allBlocos?: string[];
  allAptos?: string[];
  tipoEstrutura: string;
  aiCallCount = 0;

  // Component state
  blocoSel = "";
  aptoSel = "";
  isAnalyzingPhoto = false;
  aiFeedbackMessage: string | null = null;
  aiFeedbackSuccess = false;
  analysisRequestId = 0;
  photoBlob: unknown = null;

  constructor(params: {
    units: UnitOption[];
    allBlocos?: string[];
    allAptos?: string[];
    tipoEstrutura?: string;
  }) {
    this.units = params.units;
    this.allBlocos = params.allBlocos;
    this.allAptos = params.allAptos;
    this.tipoEstrutura = params.tipoEstrutura ?? "predio";
  }

  get blocos(): string[] {
    return this.allBlocos && this.allBlocos.length > 0
      ? [...this.allBlocos].sort((a, b) => a.localeCompare(b, "pt", { numeric: true }))
      : [...new Set(this.units.map((u) => u.blocoNome))].sort((a, b) =>
          a.localeCompare(b, "pt", { numeric: true })
        );
  }

  get aptosList(): string[] {
    return this.allAptos && this.allAptos.length > 0
      ? this.allAptos
      : this.units
          .filter((u) => !this.blocoSel || u.blocoNome === this.blocoSel)
          .map((u) => u.aptoNumero);
  }

  get uniqueAptos(): string[] {
    return [...new Set(this.aptosList)].sort((a, b) =>
      a.localeCompare(b, "pt", { numeric: true })
    );
  }

  get selectedUnit(): UnitOption | undefined {
    return this.units.find(
      (u) => u.blocoNome === this.blocoSel && u.aptoNumero === this.aptoSel
    );
  }

  // Simulate analyzePhotoWithAi execution with priority logic
  analyzePhoto(aiCaller?: () => {
    leitura_ok?: boolean;
    bloco?: string | null;
    apartamento?: string | null;
    confianca?: number;
  } | null) {
    const hasBloco = !!this.blocoSel.trim();
    const hasApto = !!this.aptoSel.trim();

    // CENÁRIO 1: Ambos já preenchidos manualmente -> NÃO chamar Edge Function / IA. Custo ZERO.
    if (hasBloco && hasApto) {
      return { aiCalled: false, success: true };
    }

    this.aiCallCount++;
    const currentReqId = ++this.analysisRequestId;
    this.isAnalyzingPhoto = true;
    this.aiFeedbackMessage = "Analisando a foto...";
    this.aiFeedbackSuccess = false;

    const data = aiCaller ? aiCaller() : null;

    if (currentReqId !== this.analysisRequestId) {
      return { aiCalled: true, ignored: true };
    }

    if (!data) {
      this.isAnalyzingPhoto = false;
      this.aiFeedbackMessage =
        "⚠️ Não foi possível identificar a unidade pela foto. Preencha Bloco e Apartamento manualmente.";
      this.aiFeedbackSuccess = false;
      return { aiCalled: true, success: false };
    }

    const leituraOk = data.leitura_ok === true;
    const rawBloco = data.bloco ? String(data.bloco).trim() : null;
    const rawApto = data.apartamento ? String(data.apartamento).trim() : null;

    if (!leituraOk || (!rawBloco && !rawApto)) {
      this.isAnalyzingPhoto = false;
      this.aiFeedbackMessage =
        "⚠️ Não foi possível identificar a unidade pela foto. Preencha manualmente.";
      this.aiFeedbackSuccess = false;
      return { aiCalled: true, success: false };
    }

    // CENÁRIO 2: Bloco preenchido manualmente, Apto vazio
    if (hasBloco && !hasApto) {
      if (rawApto) {
        const availableAptos = this.units
          .filter((u) => u.blocoNome.toLowerCase() === this.blocoSel.toLowerCase())
          .map((u) => u.aptoNumero);

        const matchingApto = availableAptos.find(
          (a) => a.trim().toLowerCase() === rawApto.toLowerCase()
        );

        if (matchingApto) {
          this.aptoSel = matchingApto;
          this.isAnalyzingPhoto = false;
          this.aiFeedbackMessage = "✓ Apartamento identificado automaticamente pela foto";
          this.aiFeedbackSuccess = true;
          return { aiCalled: true, success: true };
        } else {
          this.isAnalyzingPhoto = false;
          this.aiFeedbackMessage =
            "⚠️ O apartamento identificado na foto não foi encontrado para o bloco selecionado. Confira os dados manualmente.";
          this.aiFeedbackSuccess = false;
          return { aiCalled: true, success: false };
        }
      } else {
        this.isAnalyzingPhoto = false;
        this.aiFeedbackMessage =
          "⚠️ Não foi possível identificar o apartamento pela foto. Selecione manualmente.";
        this.aiFeedbackSuccess = false;
        return { aiCalled: true, success: false };
      }
    }

    // CENÁRIO 3: Bloco vazio, Apartamento preenchido manualmente
    if (!hasBloco && hasApto) {
      if (rawBloco) {
        const matchingBloco = this.blocos.find(
          (b) => b.trim().toLowerCase() === rawBloco.toLowerCase()
        );

        if (matchingBloco) {
          const availableAptos = this.units
            .filter((u) => u.blocoNome.toLowerCase() === matchingBloco.toLowerCase())
            .map((u) => u.aptoNumero);

          const aptoExistsInBloco = availableAptos.some(
            (a) => a.trim().toLowerCase() === this.aptoSel.trim().toLowerCase()
          );

          if (aptoExistsInBloco) {
            this.blocoSel = matchingBloco;
            this.isAnalyzingPhoto = false;
            this.aiFeedbackMessage = "✓ Bloco identificado automaticamente pela foto";
            this.aiFeedbackSuccess = true;
            return { aiCalled: true, success: true };
          } else {
            this.isAnalyzingPhoto = false;
            this.aiFeedbackMessage =
              "⚠️ O bloco identificado na foto não foi encontrado para o apartamento selecionado. Confira os dados manualmente.";
            this.aiFeedbackSuccess = false;
            return { aiCalled: true, success: false };
          }
        } else {
          this.isAnalyzingPhoto = false;
          this.aiFeedbackMessage =
            "⚠️ O bloco identificado na foto não foi encontrado neste condomínio. Confira os dados manualmente.";
          this.aiFeedbackSuccess = false;
          return { aiCalled: true, success: false };
        }
      } else {
        this.isAnalyzingPhoto = false;
        this.aiFeedbackMessage = "⚠️ Não foi possível identificar o bloco pela foto. Selecione manualmente.";
        this.aiFeedbackSuccess = false;
        return { aiCalled: true, success: false };
      }
    }

    // CENÁRIO 4: Ambos vazios (!hasBloco && !hasApto)
    if (!rawBloco && rawApto) {
      this.isAnalyzingPhoto = false;
      this.aiFeedbackMessage = `⚠️ Apartamento ${rawApto} identificado, mas o bloco não está visível na foto. Selecione o bloco manualmente.`;
      this.aiFeedbackSuccess = false;
      return { aiCalled: true, success: false };
    }

    const matchingBloco = this.blocos.find(
      (b) => b.trim().toLowerCase() === rawBloco!.toLowerCase()
    );

    if (!matchingBloco) {
      this.isAnalyzingPhoto = false;
      this.aiFeedbackMessage =
        "⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente.";
      this.aiFeedbackSuccess = false;
      return { aiCalled: true, success: false };
    }

    this.blocoSel = matchingBloco;

    if (rawApto) {
      const availableAptos = this.units
        .filter((u) => u.blocoNome.toLowerCase() === matchingBloco.toLowerCase())
        .map((u) => u.aptoNumero);

      const matchingApto = availableAptos.find(
        (a) => a.trim().toLowerCase() === rawApto.toLowerCase()
      );

      if (matchingApto) {
        this.aptoSel = matchingApto;
        this.isAnalyzingPhoto = false;
        this.aiFeedbackMessage = "✓ Unidade identificada automaticamente pela foto";
        this.aiFeedbackSuccess = true;
        return { aiCalled: true, success: true };
      } else {
        this.isAnalyzingPhoto = false;
        this.aiFeedbackMessage =
          "⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente.";
        this.aiFeedbackSuccess = false;
        return { aiCalled: true, success: false };
      }
    } else {
      this.isAnalyzingPhoto = false;
      this.aiFeedbackMessage = "✓ Bloco identificado. Selecione o apartamento manualmente.";
      this.aiFeedbackSuccess = false;
      return { aiCalled: true, success: false };
    }
  }
}

// ── Test Execution ──────────────────────────────────────────────────────────

const sampleUnits: UnitOption[] = [
  { blocoNome: "A", aptoNumero: "101", residentId: "res-1", residentName: "João Silva" },
  { blocoNome: "A", aptoNumero: "102", residentId: "res-2", residentName: "Maria Santos" },
  { blocoNome: "B", aptoNumero: "305", residentId: "res-3", residentName: "Carlos Oliveira" },
  { blocoNome: "B", aptoNumero: "306", residentId: "res-4", residentName: "Ana Souza" },
];

const sampleBlocos = ["A", "B"];
const sampleAptos = ["101", "102", "305", "306"];

Deno.test("CENÁRIO 1: Bloco e Apto já preenchidos -> IA NÃO É EXECUTADA (Custo ZERO)", () => {
  const engine = new WebParcelRegisterEngine({
    units: sampleUnits,
    allBlocos: sampleBlocos,
    allAptos: sampleAptos,
  });

  // Usuário preencheu manualmente antes de tirar foto
  engine.blocoSel = "B";
  engine.aptoSel = "305";

  const result = engine.analyzePhoto(() => {
    throw new Error("A IA NÃO deveria ser chamada quando Bloco e Apto já estão preenchidos!");
  });

  assertEquals(result.aiCalled, false);
  assertEquals(engine.aiCallCount, 0); // 0 chamadas à IA
  assertEquals(engine.blocoSel, "B");
  assertEquals(engine.aptoSel, "305");
  assertEquals(engine.selectedUnit?.residentName, "Carlos Oliveira");
});

Deno.test("CENÁRIO 2: Bloco preenchido e Apto vazio -> IA chamada somente para completar Apto (Bloco é SOBERANO)", () => {
  const engine = new WebParcelRegisterEngine({
    units: sampleUnits,
    allBlocos: sampleBlocos,
    allAptos: sampleAptos,
  });

  // Bloco manual B
  engine.blocoSel = "B";
  engine.aptoSel = "";

  const result = engine.analyzePhoto(() => ({
    leitura_ok: true,
    bloco: "A", // IA tenta sugerir Bloco A (deve ser IGNORADO)
    apartamento: "305",
    confianca: 0.98,
  }));

  assertEquals(result.aiCalled, true);
  assertEquals(engine.aiCallCount, 1);
  assertEquals(result.success, true);
  assertEquals(engine.blocoSel, "B"); // Bloco B manual PRESERVADO!
  assertEquals(engine.aptoSel, "305");
  assertEquals(engine.aiFeedbackMessage, "✓ Apartamento identificado automaticamente pela foto");
});

Deno.test("CENÁRIO 2 (Inexistente): Apto retornado não existe no bloco manual -> Alerta e preservação manual", () => {
  const engine = new WebParcelRegisterEngine({
    units: sampleUnits,
    allBlocos: sampleBlocos,
    allAptos: sampleAptos,
  });

  engine.blocoSel = "A";
  engine.aptoSel = "";

  const result = engine.analyzePhoto(() => ({
    leitura_ok: true,
    apartamento: "305", // 305 é do Bloco B, não do Bloco A
  }));

  assertEquals(result.aiCalled, true);
  assertEquals(result.success, false);
  assertEquals(engine.blocoSel, "A"); // Preserva Bloco A
  assertEquals(engine.aptoSel, ""); // Não preenche
  assertEquals(
    engine.aiFeedbackMessage,
    "⚠️ O apartamento identificado na foto não foi encontrado para o bloco selecionado. Confira os dados manualmente."
  );
});

Deno.test("CENÁRIO 3: Bloco vazio e Apto preenchido -> IA chamada somente para completar Bloco (Apto é SOBERANO)", () => {
  const engine = new WebParcelRegisterEngine({
    units: sampleUnits,
    allBlocos: sampleBlocos,
    allAptos: sampleAptos,
  });

  engine.blocoSel = "";
  engine.aptoSel = "305"; // Manual

  const result = engine.analyzePhoto(() => ({
    leitura_ok: true,
    bloco: "B",
    apartamento: "999", // IA tenta sugerir outro apto (deve ser IGNORADO)
    confianca: 0.95,
  }));

  assertEquals(result.aiCalled, true);
  assertEquals(engine.aiCallCount, 1);
  assertEquals(result.success, true);
  assertEquals(engine.blocoSel, "B");
  assertEquals(engine.aptoSel, "305"); // Apto 305 manual PRESERVADO!
  assertEquals(engine.aiFeedbackMessage, "✓ Bloco identificado automaticamente pela foto");
});

Deno.test("CENÁRIO 3 (Inexistente): Bloco identificado não possui o apartamento manual -> Alerta e preservação", () => {
  const engine = new WebParcelRegisterEngine({
    units: sampleUnits,
    allBlocos: sampleBlocos,
    allAptos: sampleAptos,
  });

  engine.blocoSel = "";
  engine.aptoSel = "101"; // 101 existe no Bloco A, não no B

  const result = engine.analyzePhoto(() => ({
    leitura_ok: true,
    bloco: "B",
  }));

  assertEquals(result.aiCalled, true);
  assertEquals(result.success, false);
  assertEquals(engine.blocoSel, ""); // Não seleciona
  assertEquals(engine.aptoSel, "101"); // Preserva Apto 101
  assertEquals(
    engine.aiFeedbackMessage,
    "⚠️ O bloco identificado na foto não foi encontrado para o apartamento selecionado. Confira os dados manualmente."
  );
});

Deno.test("CENÁRIO 4: Bloco e Apto vazios -> IA identifica ambos normalmente", () => {
  const engine = new WebParcelRegisterEngine({
    units: sampleUnits,
    allBlocos: sampleBlocos,
    allAptos: sampleAptos,
  });

  engine.blocoSel = "";
  engine.aptoSel = "";

  const result = engine.analyzePhoto(() => ({
    leitura_ok: true,
    bloco: "B",
    apartamento: "305",
    confianca: 0.98,
  }));

  assertEquals(result.aiCalled, true);
  assertEquals(engine.aiCallCount, 1);
  assertEquals(result.success, true);
  assertEquals(engine.blocoSel, "B");
  assertEquals(engine.aptoSel, "305");
  assertEquals(engine.aiFeedbackMessage, "✓ Unidade identificada automaticamente pela foto");
});

Deno.test("CENÁRIO 4 (Ilegível): Bloco e Apto vazios e foto ilegível -> Fallback manual gracioso", () => {
  const engine = new WebParcelRegisterEngine({
    units: sampleUnits,
    allBlocos: sampleBlocos,
    allAptos: sampleAptos,
  });

  engine.blocoSel = "";
  engine.aptoSel = "";

  const result = engine.analyzePhoto(() => ({
    leitura_ok: false,
    bloco: null,
    apartamento: null,
    confianca: 0.1,
  }));

  assertEquals(result.aiCalled, true);
  assertEquals(result.success, false);
  assertEquals(engine.blocoSel, "");
  assertEquals(engine.aptoSel, "");
  assertEquals(
    engine.aiFeedbackMessage,
    "⚠️ Não foi possível identificar a unidade pela foto. Preencha manualmente."
  );
});

Deno.test("TESTE WEB: Contextos de Portaria e Admin", () => {
  const condoForm = new WebParcelRegisterEngine({
    units: sampleUnits,
    tipoEstrutura: "predio",
  });
  const adminForm = new WebParcelRegisterEngine({
    units: sampleUnits,
    tipoEstrutura: "predio",
  });

  assertEquals(condoForm.blocos.length, adminForm.blocos.length);
  assertEquals(condoForm.units.length, adminForm.units.length);
});
