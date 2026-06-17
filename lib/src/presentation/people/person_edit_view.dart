import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class PersonEditView extends StatelessWidget {
  final Person person;
  const PersonEditView({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<IPersonRepository>();

    return PersonForm(
      title: 'Editar Membro',
      initial: PersonInput.fromPerson(person),
      onSubmit: (input) async {
        final updated = input.toPersonWithId(person.id);
        await repo.update(updated);
        Navigator.of(context).pop(true);
      },
    );
  }
}

