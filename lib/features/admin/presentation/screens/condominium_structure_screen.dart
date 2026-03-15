import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import '../bloc/structure_bloc.dart';
import '../bloc/structure_event.dart';
import '../bloc/structure_state.dart';

class CondominiumStructureScreen extends StatefulWidget {
  const CondominiumStructureScreen({super.key});

  @override
  State<CondominiumStructureScreen> createState() => _CondominiumStructureScreenState();
}

class _CondominiumStructureScreenState extends State<CondominiumStructureScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _blocosScrollController;
  late ScrollController _aptosScrollController;
  late ScrollController _unidadesScrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _blocosScrollController = ScrollController();
    _aptosScrollController = ScrollController();
    _unidadesScrollController = ScrollController();
    
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId != null) {
      context.read<StructureBloc>().add(StructureStarted(condoId));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _blocosScrollController.dispose();
    _aptosScrollController.dispose();
    _unidadesScrollController.dispose();
    super.dispose();
  }

  String? get _condoId => context.read<AuthBloc>().state.condominiumId;
  String? get _tipoEstrutura => context.read<AuthBloc>().state.tipoEstrutura;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Estrutura do Condomínio',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: const Icon(Icons.business), text: '${StructureHelper.getNivel1Label(_tipoEstrutura)}s'),
            Tab(icon: const Icon(Icons.door_front_door), text: '${StructureHelper.getNivel2Label(_tipoEstrutura)}s'),
            const Tab(icon: Icon(Icons.grid_view), text: 'Unidades'),
          ],
        ),
      ),
      body: BlocConsumer<StructureBloc, StructureState>(
        listener: (context, state) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ),
            );
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == StructureStatus.loading &&
              state.blocos.isEmpty && state.apartamentos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _buildBlocosTab(state),
              _buildApartamentosTab(state),
              _buildUnidadesTab(state),
            ],
          );
        },
      ),
    );
  }

  // ── TAB 1: BLOCOS ──

  Widget _buildBlocosTab(StructureState state) {
    return Stack(
      children: [
        Scrollbar(
          controller: _blocosScrollController,
          thumbVisibility: true,
          child: ListView(
            controller: _blocosScrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.all(16),
            children: [
              if (state.blocos.isEmpty)
                _buildEmptyState(
                  Icons.business,
                  'Nenhum(a) ${StructureHelper.getNivel1Label(_tipoEstrutura).toLowerCase()} cadastrado(a).',
                  'Adicionar Primeiro(a) ${StructureHelper.getNivel1Label(_tipoEstrutura)}',
                  () => _showAddDialog(
                    title: 'Adicionar ${StructureHelper.getNivel1Label(_tipoEstrutura)}',
                    hint: StructureHelper.getNivel1Hint(_tipoEstrutura),
                    label: 'Nome ou Número',
                    onAdd: (value) {
                      if (_condoId != null) {
                        context.read<StructureBloc>().add(
                              BlocoAdded(condominiumId: _condoId!, nomeOuNumero: value),
                            );
                      }
                    },
                  ),
                )
              else
                ...state.blocos.where((b) => b.nomeOuNumero != '0').map((b) => _buildItemCard(
                  icon: Icons.business,
                  title: b.nomeOuNumero,
                  onDelete: () => context.read<StructureBloc>().add(BlocoDeleted(b.id)),
                )),
              const SizedBox(height: 80),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_bloco',
            onPressed: () => _showAddDialog(
              title: 'Adicionar ${StructureHelper.getNivel1Label(_tipoEstrutura)}',
              hint: StructureHelper.getNivel1Hint(_tipoEstrutura),
              label: 'Nome ou Número',
              onAdd: (value) {
                if (_condoId != null) {
                  context.read<StructureBloc>().add(
                        BlocoAdded(condominiumId: _condoId!, nomeOuNumero: value),
                      );
                }
              },
            ),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ── TAB 2: APARTAMENTOS ──

  Widget _buildApartamentosTab(StructureState state) {
    final aptos = state.apartamentos.where((a) => a.numero != '0').toList();
    return Stack(
      children: [
        Scrollbar(
          controller: _aptosScrollController,
          thumbVisibility: true,
          child: aptos.isEmpty
            ? ListView(
                controller: _aptosScrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                children: [
                  _buildEmptyState(
                    Icons.door_front_door,
                    'Nenhum(a) ${StructureHelper.getNivel2Label(_tipoEstrutura).toLowerCase()} cadastrado(a).',
                    'Adicionar Primeiro(a) ${StructureHelper.getNivel2Label(_tipoEstrutura)}',
                    () => _showAddDialog(
                      title: 'Adicionar ${StructureHelper.getNivel2Label(_tipoEstrutura)}',
                      hint: StructureHelper.getNivel2Hint(_tipoEstrutura),
                      label: 'Número',
                      onAdd: (value) {
                        if (_condoId != null) {
                          context.read<StructureBloc>().add(
                                ApartamentoAdded(condominiumId: _condoId!, numero: value),
                              );
                        }
                      },
                    ),
                  ),
                ],
              )
            : GridView.builder(
                controller: _aptosScrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemCount: aptos.length,
                itemBuilder: (context, index) {
                  final a = aptos[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.home_outlined, color: AppColors.primary, size: 20),
                              const SizedBox(height: 2),
                              Text(a.numero,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showDeleteConfirmation(
                              'Excluir Apto \${a.numero}?',
                              () => context.read<StructureBloc>().add(ApartamentoDeleted(a.id)),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(10),
                                  bottomLeft: Radius.circular(8),
                                ),
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_apto',
            onPressed: () => _showAddDialog(
              title: 'Adicionar ${StructureHelper.getNivel2Label(_tipoEstrutura)}',
              hint: StructureHelper.getNivel2Hint(_tipoEstrutura),
              label: 'Número',
              onAdd: (value) {
                if (_condoId != null) {
                  context.read<StructureBloc>().add(
                        ApartamentoAdded(condominiumId: _condoId!, numero: value),
                      );
                }
              },
            ),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

    // ── TAB 3: UNIDADES ──

  Widget _buildUnidadesTab(StructureState state) {
    return Scrollbar(
      controller: _unidadesScrollController,
      thumbVisibility: true,
      child: ListViewUnidades(
        controller: _unidadesScrollController,
        state: state,
        tipoEstrutura: _tipoEstrutura,
        onGenerate: () => _showGenerateUnidadesDialog(state),
        onDelete: (id) => context.read<StructureBloc>().add(UnidadeDeleted(id)),
      ),
    );
  }

  // ── DIALOGS REUTILIZÁVEIS ──

  void _showAddDialog({
    required String title,
    required String hint,
    required String label,
    required void Function(String) onAdd,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint, labelText: label),
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              onAdd(value.trim());
              Navigator.pop(dialogCtx);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onAdd(controller.text.trim());
                Navigator.pop(dialogCtx);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showGenerateUnidadesDialog(StructureState state) {
    // Pre-filter placeholders and auto-select all on open
    final validBlocos = state.blocos.where((b) => b.nomeOuNumero != '0').toList();
    final validAptos = state.apartamentos.where((a) => a.numero != '0').toList();
    final selectedBlocos = <String>{...validBlocos.map((b) => b.id)};
    final selectedAptos = <String>{...validAptos.map((a) => a.id)};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Gerar Unidades'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('Selecione os(as) ${StructureHelper.getNivel1Label(_tipoEstrutura)}s:', style: const TextStyle(fontWeight: FontWeight.bold))),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            if (selectedBlocos.length == validBlocos.length) {
                              selectedBlocos.clear();
                            } else {
                              selectedBlocos.addAll(validBlocos.map((b) => b.id));
                            }
                          });
                        },
                        child: Text(
                          selectedBlocos.length == validBlocos.length
                              ? 'Desmarcar todos'
                              : 'Selecionar todos',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: state.blocos.where((b) => b.nomeOuNumero != '0').map((b) {
                      final selected = selectedBlocos.contains(b.id);
                      return FilterChip(
                        label: Text(b.nomeOuNumero),
                        selected: selected,
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) {
                              selectedBlocos.add(b.id);
                            } else {
                              selectedBlocos.remove(b.id);
                            }
                          });
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('Selecione os(as) ${StructureHelper.getNivel2Label(_tipoEstrutura)}s:', style: const TextStyle(fontWeight: FontWeight.bold))),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            if (selectedAptos.length == validAptos.length) {
                              selectedAptos.clear();
                            } else {
                              selectedAptos.addAll(validAptos.map((a) => a.id));
                            }
                          });
                        },
                        child: Text(
                          selectedAptos.length == validAptos.length
                              ? 'Desmarcar todos'
                              : 'Selecionar todos',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: state.apartamentos.where((a) => a.numero != '0').map((a) {
                      final selected = selectedAptos.contains(a.id);
                      return FilterChip(
                        label: Text(a.numero),
                        selected: selected,
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) {
                              selectedAptos.add(a.id);
                            } else {
                              selectedAptos.remove(a.id);
                            }
                          });
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                  if (selectedBlocos.isNotEmpty && selectedAptos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        int total = selectedBlocos.length * selectedAptos.length;
                        int existing = 0;
                        for (var b in selectedBlocos) {
                          for (var a in selectedAptos) {
                            if (state.unidades.any((u) => u.blocoId == b && u.apartamentoId == a)) {
                              existing++;
                            }
                          }
                        }
                        int toCreate = total - existing;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$total combinações selecionadas',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              if (toCreate > 0)
                                Text(
                                  '✨ $toCreate novas unidades serão criadas.',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                )
                              else
                                const Text(
                                  '✅ Todas as unidades selecionadas já existem.',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: selectedBlocos.isNotEmpty && selectedAptos.isNotEmpty
                  ? () {
                      context.read<StructureBloc>().add(UnidadesGenerated(
                        condominiumId: _condoId!,
                        blocoIds: selectedBlocos.toList(),
                        apartamentoIds: selectedAptos.toList(),
                      ));
                      Navigator.pop(ctx);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Gerar Unidades'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message, String btnLabel, VoidCallback onTab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onTab,
            icon: const Icon(Icons.add),
            label: Text(btnLabel),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard({
    required IconData icon,
    required String title,
    required VoidCallback onDelete,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE0E0E0),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _showDeleteConfirmation(
            'Excluir "$title"? Todas as unidades vinculadas a este bloco serão removidas.',
            onDelete,
          ),
        ),
      ),
    );
  }
}

class ListViewUnidades extends StatelessWidget {
  final ScrollController controller;
  final StructureState state;
  final String? tipoEstrutura;
  final VoidCallback onGenerate;
  final Function(String) onDelete;

  const ListViewUnidades({
    super.key,
    required this.controller,
    required this.state,
    this.tipoEstrutura,
    required this.onGenerate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        if (state.blocos.isNotEmpty && state.apartamentos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Gerar Unidades'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (state.blocos.isEmpty || state.apartamentos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'Cadastre pelo menos 1 ${StructureHelper.getNivel1Label(tipoEstrutura).toLowerCase()} e 1 ${StructureHelper.getNivel2Label(tipoEstrutura).toLowerCase()}\npara poder gerar as Unidades.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        if (state.unidades.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('Nenhuma unidade gerada ainda.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: state.unidades
              .where((u) => u.blocoNome != '0' && u.aptoNumero != '0')
              .map((u) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.home, color: AppColors.primary),
                      title: Text(StructureHelper.getFullUnitName(
                          tipoEstrutura, u.blocoNome ?? "?", u.aptoNumero ?? "?")),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => onDelete(u.id),
                      ),
                    ),
                  )).toList(),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}
