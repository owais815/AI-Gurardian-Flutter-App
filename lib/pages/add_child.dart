import 'package:flutter/material.dart';
import 'package:parental_control/pages/device_selection_screen.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  _AddChildScreenState createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();

  String _childName = '';
  String _selectedGender = 'Boy';
  String? _selectedYear;

  final List<String> _genders = ['Boy', 'Girl'];
  final List<String> _years = List.generate(
    25,
    (index) => (DateTime.now().year - index).toString(),
  );

  bool get _isFormComplete =>
      _childName.isNotEmpty &&
      _selectedGender.isNotEmpty &&
      _selectedYear != null;

  void _onFormFieldChanged() {
    setState(() {}); // Update UI to reflect changes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: const Text('Add a child', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 1),
              const Center(
                child: Icon(Icons.edit, color: Colors.green, size: 30),
              ),
              const SizedBox(height: 30),

              const Text(
                'Name',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: "Child's first name",
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.deepPurple),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (val) {
                  _childName = val;
                  _onFormFieldChanged();
                },
                validator:
                    (val) =>
                        val == null || val.isEmpty
                            ? 'Please enter a name'
                            : null,
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gender',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          items:
                              _genders.map((gender) {
                                return DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                );
                              }).toList(),
                          onChanged: (value) {
                            _selectedGender = value!;
                            _onFormFieldChanged();
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Birth year',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedYear,
                          hint: const Text('-'),
                          items:
                              _years.map((year) {
                                return DropdownMenuItem(
                                  value: year,
                                  child: Text(year),
                                );
                              }).toList(),
                          onChanged: (value) {
                            _selectedYear = value;
                            _onFormFieldChanged();
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator:
                              (val) => val == null ? 'Select year' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isFormComplete
                          ? () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => DeviceSelectionScreen(
                                        childName: _childName,
                                      ),
                                ),
                              );
                              // print('Child Name: $_childName');
                              // print('Gender: $_selectedGender');
                              // print('Year: $_selectedYear');
                            }
                          }
                          : null, // Disabled if form is incomplete
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isFormComplete
                            ? Colors
                                .deepPurple // Enabled color
                            : Colors.deepPurple.shade100, // Disabled color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),

                  child: const Text(
                    'Next ➔',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
