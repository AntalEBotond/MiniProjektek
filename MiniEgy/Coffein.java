import java.util.Scanner;

public class Coffein {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        System.out.println("Lépések:");
        System.out.println("1. Pohár nélkül");
        System.out.println("2. Dupla cukorral");
        System.out.println("3. Habos kávé");

        int choice = scanner.nextInt();
        int price = 100;  // Ár BASE

        switch (choice) {
            case 2:
                price += 20;
                break;
            case 3:
                price += 50;
                break;
            case 1:
                price -= 10;
                break;
            default:
                System.out.println("Hibás!");
                return;
        }

        System.out.println("A fizetendő összeg: " + price + " Ft");
    }
}