public class Film {
    private String cim;
    private int ar;
    private int[] velemenyek;
    private int velemenyekSzama;

    public Film(String cim, int ar) {
        this.cim = cim;
        this.ar = ar;
        this.velemenyek = new int[20];
        this.velemenyekSzama = 0;
    }

    public String getCim() {
        return cim;
    }

    public int getAr() {
        return ar;
    }

    public void setAr(int ar) {
        this.ar = ar;
    }

    public void Velemenyezes(int velemeny) {
        if (velemenyekSzama < 20 && velemeny >= 1 && velemeny <= 5) {
            velemenyek[velemenyekSzama++] = velemeny;
        }
    }

    public double Atlag() {
        if (velemenyekSzama == 0) {
            throw new IllegalStateException("A film még nem kapott véleményt.");
        }
        int osszeg = 0;
        for (int i = 0; i < velemenyekSzama; i++) {
            osszeg += velemenyek[i];
        }
        return (double) osszeg / velemenyekSzama;
    }

    @Override
    public String toString() {
        return "Film címe: " + cim + ", Film ára: " + ar;
    }
}
