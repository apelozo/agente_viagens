class UserModel {
  final int id;
  final String nome;
  final String tipo;
  final String email;

  UserModel({required this.id, required this.nome, required this.tipo, required this.email});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(id: json['id'], nome: json['nome'], tipo: json['tipo'], email: json['email']);
  }
}
