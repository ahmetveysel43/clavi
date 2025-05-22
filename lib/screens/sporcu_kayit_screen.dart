import 'package:flutter/material.dart';
import '../models/sporcu_model.dart';
import '../services/database_service.dart';

class SporcuKayitScreen extends StatefulWidget {
  final Sporcu? sporcu;

  const SporcuKayitScreen({super.key, this.sporcu});

  @override
  _SporcuKayitScreenState createState() => _SporcuKayitScreenState();
}

class _SporcuKayitScreenState extends State<SporcuKayitScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;

  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _yasController = TextEditingController();
  final _cinsiyetController = TextEditingController();
  final _bransController = TextEditingController();
  final _kulupController = TextEditingController();
  final _sikletYasController = TextEditingController();
  final _sikletKiloController = TextEditingController();
  final _sporculukYiliController = TextEditingController();
  final _boyController = TextEditingController();
  final _kiloController = TextEditingController();
  final _bacakBoyuController = TextEditingController();
  final _oturmaBoyuController = TextEditingController();

  String _selectedCinsiyet = 'Erkek';
  final List<String> _cinsiyetler = ['Erkek', 'Kadın'];

  @override
  void initState() {
    super.initState();
    if (widget.sporcu != null) {
      _adController.text = widget.sporcu!.ad;
      _soyadController.text = widget.sporcu!.soyad;
      _yasController.text = widget.sporcu!.yas.toString();
      _selectedCinsiyet = widget.sporcu!.cinsiyet;
      _bransController.text = widget.sporcu!.brans ?? '';
      _kulupController.text = widget.sporcu!.kulup ?? '';
      _sikletYasController.text = widget.sporcu!.sikletYas ?? '';
      _sikletKiloController.text = widget.sporcu!.sikletKilo ?? '';
      _sporculukYiliController.text = widget.sporcu!.sporculukYili ?? '';
      _boyController.text = widget.sporcu!.boy ?? '';
      _kiloController.text = widget.sporcu!.kilo ?? '';
      _bacakBoyuController.text = widget.sporcu!.bacakBoyu ?? '';
      _oturmaBoyuController.text = widget.sporcu!.oturmaBoyu ?? '';
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _yasController.dispose();
    _cinsiyetController.dispose();
    _bransController.dispose();
    _kulupController.dispose();
    _sikletYasController.dispose();
    _sikletKiloController.dispose();
    _sporculukYiliController.dispose();
    _boyController.dispose();
    _kiloController.dispose();
    _bacakBoyuController.dispose();
    _oturmaBoyuController.dispose();
    super.dispose();
  }

  Future<void> _saveSporcu() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        Sporcu sporcu = Sporcu(
          id: widget.sporcu?.id,
          ad: _adController.text,
          soyad: _soyadController.text,
          yas: int.parse(_yasController.text),
          cinsiyet: _selectedCinsiyet,
          brans: _bransController.text.isEmpty ? null : _bransController.text,
          kulup: _kulupController.text.isEmpty ? null : _kulupController.text,
          sikletYas: _sikletYasController.text.isEmpty ? null : _sikletYasController.text,
          sikletKilo: _sikletKiloController.text.isEmpty ? null : _sikletKiloController.text,
          sporculukYili: _sporculukYiliController.text.isEmpty ? null : _sporculukYiliController.text,
          boy: _boyController.text.isEmpty ? null : _boyController.text,
          kilo: _kiloController.text.isEmpty ? null : _kiloController.text,
          bacakBoyu: _bacakBoyuController.text.isEmpty ? null : _bacakBoyuController.text,
          oturmaBoyu: _oturmaBoyuController.text.isEmpty ? null : _oturmaBoyuController.text,
        );

        if (widget.sporcu == null) {
          await _databaseService.insertSporcu(sporcu);
          _databaseService.clearCache();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sporcu başarıyla kaydedildi'),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
          );
        } else {
          await _databaseService.updateSporcu(sporcu);
          _databaseService.clearCache();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sporcu başarıyla güncellendi'),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
          );
        }

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sporcu == null ? 'Sporcu Kayıt' : 'Sporcu Güncelle'),
        backgroundColor: const Color(0xFF0288D1),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE3F2FD), Colors.white],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(
                        'Temel Bilgiler',
                        Icons.person,
                        const Color(0xFF1E88E5),
                        Column(
                          children: [
                            _buildTextField(
                              controller: _adController,
                              labelText: 'Ad *',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ad zorunludur';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _soyadController,
                              labelText: 'Soyad *',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Soyad zorunludur';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _yasController,
                              labelText: 'Yaş *',
                              icon: Icons.calendar_today,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Yaş zorunludur';
                                }
                                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                                  return 'Geçerli bir yaş girin';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              value: _selectedCinsiyet,
                              labelText: 'Cinsiyet *',
                              icon: Icons.person,
                              items: _cinsiyetler.map((cinsiyet) {
                                return DropdownMenuItem(
                                  value: cinsiyet,
                                  child: Text(cinsiyet),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCinsiyet = value!;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Cinsiyet seçimi zorunludur';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        'Spor Bilgileri',
                        Icons.sports,
                        const Color(0xFF43A047),
                        Column(
                          children: [
                            _buildTextField(
                              controller: _bransController,
                              labelText: 'Branş',
                              icon: Icons.category,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _kulupController,
                              labelText: 'Kulüp',
                              icon: Icons.group,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _sporculukYiliController,
                              labelText: 'Sporculuk Yılı',
                              icon: Icons.timer,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        'Fiziksel Bilgiler',
                        Icons.accessibility_new,
                        const Color(0xFFFB8C00),
                        Column(
                          children: [
                            _buildTextField(
                              controller: _boyController,
                              labelText: 'Boy (cm)',
                              icon: Icons.height,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _kiloController,
                              labelText: 'Kilo (kg)',
                              icon: Icons.monitor_weight,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _bacakBoyuController,
                              labelText: 'Bacak Boyu (cm)',
                              icon: Icons.straighten,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _oturmaBoyuController,
                              labelText: 'Oturma Boyu (cm)',
                              icon: Icons.airline_seat_recline_normal,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        'Ek Bilgiler',
                        Icons.info_outline,
                        const Color(0xFF9C27B0),
                        Column(
                          children: [
                            _buildTextField(
                              controller: _sikletYasController,
                              labelText: 'Siklet Yaş',
                              icon: Icons.cake,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _sikletKiloController,
                              labelText: 'Siklet Kilo',
                              icon: Icons.monitor_weight,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveSporcu,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0288D1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            widget.sporcu == null ? 'Kaydet' : 'Güncelle',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, Color color, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: const Color(0xFF0288D1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0288D1), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String labelText,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: const Color(0xFF0288D1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0288D1), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
      dropdownColor: Colors.white,
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0288D1)),
    );
  }
}