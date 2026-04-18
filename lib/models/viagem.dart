class Viagem {
  final int id;
  final String descricao;
  final String dataInicial;
  final String dataFinal;
  final String situacao;
  final int userId;

  Viagem({
    required this.id,
    required this.descricao,
    required this.dataInicial,
    required this.dataFinal,
    required this.situacao,
    required this.userId,
  });

  factory Viagem.fromJson(Map<String, dynamic> json) => Viagem(
        id: json['id'],
        descricao: json['descricao'],
        dataInicial: json['data_inicial'],
        dataFinal: json['data_final'],
        situacao: json['situacao'],
        userId: json['user_id'],
      );
}
