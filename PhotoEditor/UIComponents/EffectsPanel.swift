import SwiftUI

struct EffectsPanel: View {
    @ObservedObject var model: DocumentModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Effects")
                .font(.headline)
                .padding(.horizontal)
            
            if let activeId = model.activeLayerId,
               let index = model.layers.firstIndex(where: { $0.id == activeId }) {
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(model.layers[index].effects.indices, id: \.self) { effectIndex in
                            EffectControlRow(effect: $model.layers[index].effects[effectIndex])
                        }
                        
                        addEffectButton(for: index)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("No Layer Selected", systemImage: "layer.stack.3d.up.slash")
            }
        }
        .frame(width: 250)
        .background(.ultraThinMaterial)
    }
    
    private func addEffectButton(for layerIndex: Int) -> some View {
        Menu {
            ForEach(EffectType.allCases, id: \.self) { type in
                Button(type.rawValue) {
                    addEffect(type, to: layerIndex)
                }
            }
        } label: {
            Label("Add Effect", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
    }
    
    private func addEffect(_ type: EffectType, to index: Int) {
        let newEffect = LayerEffect(type: type, parameters: ["intensity": 0.5])
        model.layers[index].effects.append(newEffect)
    }
}

struct EffectControlRow: View {
    @Binding var effect: LayerEffect
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $effect.isEnabled)
                    .toggleStyle(.checkbox)
                Text(effect.type.rawValue)
                    .font(.subheadline)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if effect.isEnabled {
                ForEach(effect.parameters.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(key.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f", effect.parameters[key] ?? 0))
                                .font(.caption2)
                                .monospacedDigit()
                        }
                        
                        Slider(value: Binding(
                            get: { effect.parameters[key] ?? 0 },
                            set: { effect.parameters[key] = $0 }
                        ), in: 0...1)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
    }
}
